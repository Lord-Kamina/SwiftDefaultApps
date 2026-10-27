/*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
* ----------------------------------------------------------------------------
*/

import AppKit
import UniformTypeIdentifiers

/** The four lists the app can browse. */
enum Category: String, CaseIterable, Identifiable {
	case internet = "Internet"
	case schemes = "URL Schemes"
	case types = "File Types"
	case apps = "Applications"
	var id: Self { self }
}

/** Launch Services handler roles. `all` is what Finder's "Change All…" uses. */
enum Role: String, CaseIterable, Identifiable {
	case all = "All Roles", viewer = "Viewer", editor = "Editor", shell = "Shell"
	var id: Self { self }

	var mask: LSRolesMask {
		switch self {
		case .all: return .all
		case .viewer: return .viewer
		case .editor: return .editor
		case .shell: return .shell
		}
	}
	/** Roles queried to report the current default; mirrors how Launch Services resolves "open". */
	var queryMask: LSRolesMask { self == .all ? [.viewer, .editor] : mask }
}

/** Content and applications an application declares it can open. */
struct AppDeclarations: Hashable {
	let path: String
	let version: String?
	let schemes: [String]
	let types: [String]
}

/** One row of the sidebar: a URL scheme, a UTI or an application. */
struct Entry: Identifiable, Hashable {
	enum Kind: Hashable {
		case scheme
		case type
		case app(AppDeclarations)
	}
	/** Scheme, UTI or bundle identifier. */
	let id: String
	let kind: Kind
	let title: String
	let subtitle: String
	/** File extensions of a UTI, lowercased and without the leading dot. */
	var extensions: [String] = []
	/** Broad kind of a UTI ("Images", "Source Code"…), used for grouping. */
	var kindGroup: String? = nil

	var isApp: Bool { if case .app = kind { return true } else { return false } }

	/** Search rank, lower is better; nil when the entry does not match. */
	func rank(for query: String) -> Int? {
		let q = query.lowercased()
		let ext = q.hasPrefix(".") ? String(q.dropFirst()) : q
		let id = self.id.lowercased(), title = self.title.lowercased()
		if extensions.contains(ext) || id == q || title == q { return 0 }
		if id.hasPrefix(q) || title.hasPrefix(q) || extensions.contains(where: { $0.hasPrefix(ext) }) { return 1 }
		if id.contains(q) || title.contains(q) || subtitle.lowercased().contains(q) { return 2 }
		return nil
	}
}

/** An application that can act as a handler. */
struct AppRef: Identifiable, Hashable {
	let id: String
	let name: String
	let path: String?

	static let doNothingID = "cl.fail.lordkamina.ThisAppDoesNothing"

	init?(bundleID: String) {
		guard bundleID.caseInsensitiveCompare(AppRef.doNothingID) != .orderedSame else { return nil }
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
		self.id = bundleID
		self.path = url.path
		self.name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
	}
}

/** Applications that can open a scheme or UTI, and the bundle ID of the current default. */
struct HandlerState {
	let candidates: [AppRef]
	let current: String?

	func isCurrent(_ bundleID: String) -> Bool { current?.caseInsensitiveCompare(bundleID) == .orderedSame }

}

/** Builds the sidebar lists from Launch Services. Everything here is synchronous and meant to run off the main thread. */
enum Catalog {
	private static let internetSchemes: [(String, String)] = [
		("http", "Web Browser"), ("mailto", "E-Mail"), ("news", "News"),
		("rss", "RSS"), ("ftp", "FTP"), ("im", "Instant Messaging"),
	]

	static func load(_ category: Category) -> [Entry] {
		switch category {
		case .internet:
			return internetSchemes.map { Entry(id: $0.0, kind: .scheme, title: $0.1, subtitle: "\($0.0):") }
		case .schemes:
			let schemes = (LSWrappers.Schemes.copySchemesAndHandlers()?.keys).map(Array.init) ?? []
			return concurrentMap(schemes.filter { $0 != "*" }) { scheme in
				Entry(id: scheme, kind: .scheme, title: scheme, subtitle: LSWrappers.Schemes.getNameForScheme(scheme) ?? "")
			}.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
		case .types:
			let identifiers = (UTCopyDeclaredTypeIdentifiers() as? [String]) ?? []
			return concurrentMap(identifiers) { identifier -> Entry? in
				guard let type = UTType(identifier), type.conforms(to: .item) || type.conforms(to: .content) else { return nil }
				let extensions = (type.tags[.filenameExtension] ?? []).map { $0.lowercased() }
				let description = type.localizedDescription ?? identifier
				let subtitle = extensions.isEmpty ? identifier : "\(identifier) · " + extensions.map { ".\($0)" }.joined(separator: " ")
				return Entry(id: identifier, kind: .type, title: description, subtitle: subtitle, extensions: extensions, kindGroup: kindGroup(of: type))
			}.compactMap { $0 }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
		case .apps:
			let paths = LSWrappers.copyAllApps() ?? []
			let apps = concurrentMap(paths) { path -> Entry? in
				guard let bundle = Bundle(path: path), let bundleID = bundle.bundleIdentifier,
					  bundleID.caseInsensitiveCompare(AppRef.doNothingID) != .orderedSame,
					  let declared = LSWrappers.copySchemesAndUTIsForApp(path) else { return nil }
				let schemes = declared["URIs"]?.values.reduce(into: Set<String>()) { $0.formUnion($1) } ?? []
				let types = declared["UTIs"]?.values.reduce(into: Set<String>()) { $0.formUnion($1) } ?? []
				guard !schemes.isEmpty || !types.isEmpty else { return nil }
				let info = bundle.infoDictionary ?? [:]
				let name = [info["CFBundleDisplayName"], info["CFBundleName"]].compactMap { $0 as? String }.first { !$0.isEmpty }
					?? FileManager.default.displayName(atPath: path)
				let version = (info["CFBundleShortVersionString"] ?? info["CFBundleVersion"]) as? String
				let declarations = AppDeclarations(path: path, version: version, schemes: schemes.sorted(), types: types.sorted())
				return Entry(id: bundleID, kind: .app(declarations), title: name, subtitle: bundleID)
			}.compactMap { $0 }
			// Launch Services resolves a bundle ID to a single copy, so duplicates are meaningless.
			var seen = Set<String>()
			return apps.filter { seen.insert($0.id.lowercased()).inserted }
				.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
		}
	}

	/** Candidate handlers and the current default for a scheme or UTI in a given role. */
	static func handlers(for content: String, isScheme: Bool, role: Role = .all) -> HandlerState {
		let ids: [String]
		let current: String?
		if isScheme {
			ids = LSWrappers.Schemes.copyAllHandlers(content, asPath: false) ?? []
			current = LSWrappers.Schemes.copyDefaultHandler(content, asPath: false)
		} else {
			ids = LSWrappers.UTType.copyAllHandlers(content, inRoles: role.mask, asPath: false) ?? []
			current = defaultHandler(forType: content, role: role)
		}
		var seen = Set<String>()
		let candidates = (ids + [current].compactMap { $0 })
			.filter { seen.insert($0.lowercased()).inserted }
			.compactMap(AppRef.init(bundleID:))
			.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
		return HandlerState(candidates: candidates, current: current)
	}

	static func defaultHandler(forType identifier: String, role: Role = .all) -> String? {
		LSWrappers.UTType.copyDefaultHandler(identifier, inRoles: role.queryMask, asPath: false)
	}

	/** Default handler of each UTI, keyed by UTI; UTIs without one are omitted. */
	static func defaultHandlers(forTypes identifiers: [String]) -> [String: String] {
		let pairs = concurrentMap(identifiers) { id in defaultHandler(forType: id).map { (id, $0) } }
		return Dictionary(pairs.compactMap { $0 }, uniquingKeysWith: { a, _ in a })
	}

	/** Broad kinds, most specific first: a UTI lands in the first kind it conforms to. */
	private static let kinds: [(String, [UTType])] = [
		("Source Code", [.sourceCode, .script, .shellScript]),
		("Images", [.image]),
		("Audio", [.audio]),
		("Video", [.movie, .audiovisualContent]),
		("Spreadsheets", [.spreadsheet]),
		("Presentations", [.presentation]),
		("Documents", [.pdf, .rtf, .rtfd, .compositeContent]),
		("Data", [.json, .xml, .yaml, .propertyList, .database, .commaSeparatedText, .tabSeparatedText]),
		("Text", [.text]),
		("Archives", [.archive]),
		("Fonts", [.font]),
		("3D & Models", [.threeDContent]),
		("Disk Images", [.diskImage]),
		("Apps & Bundles", [.application, .executable, .bundle, .package]),
	]

	static func kindGroup(of type: UTType) -> String {
		kinds.first { $0.1.contains { type.conforms(to: $0) } }?.0 ?? "Other"
	}

	/** Order of kind groups in the sidebar. */
	static let kindOrder: [String] = kinds.map(\.0) + ["Other"]

	/** Sets the default handler. Returns an error message, or nil on success. */
	static func setDefault(_ bundleID: String, for content: String, isScheme: Bool, role: Role = .all) -> String? {
		let status = isScheme
			? LSWrappers.Schemes.setDefaultHandler(content, bundleID)
			: LSWrappers.UTType.setDefaultHandler(content, bundleID, role.mask)
		return status == 0 ? nil : LSWrappers.LSErrors(value: status).print(argument: (app: bundleID, content: content))
	}

	/**
	Waits until a default change requested with `setDefault` has really taken effect and returns the handler
	actually in place. Launch Services applies changes asynchronously, and some of them (the default web
	browser, for instance) only after the user confirms a CoreServicesUIAgent prompt, which they may decline.
	*/
	static func settledDefault(for content: String, isScheme: Bool, role: Role = .all, target: String) async -> (handler: String?, prompted: Bool) {
		func current() -> String? {
			isScheme ? LSWrappers.Schemes.copyDefaultHandler(content, asPath: false) : defaultHandler(forType: content, role: role)
		}
		let start = Date()
		var sawPrompt = false
		while true {
			let value = current()
			if value?.caseInsensitiveCompare(target) == .orderedSame { return (value, sawPrompt) }
			let prompting = isConfirmationPromptVisible()
			if prompting { sawPrompt = true }
			let elapsed = Date().timeIntervalSince(start)
			if sawPrompt && !prompting {
				// The prompt was answered; give Launch Services a moment to apply an approval.
				try? await Task.sleep(nanoseconds: 500_000_000)
				return (current(), true)
			}
			if (!sawPrompt && elapsed > 3) || elapsed > 300 { return (value, sawPrompt) }
			try? await Task.sleep(nanoseconds: 200_000_000)
		}
	}

	/** Whether CoreServicesUIAgent is showing a "change default application" confirmation. */
	private static func isConfirmationPromptVisible() -> Bool {
		let agents = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.coreservices.uiagent").map(\.processIdentifier))
		guard !agents.isEmpty,
			  let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
		else { return false }
		return windows.contains { ($0[kCGWindowOwnerPID as String] as? pid_t).map(agents.contains) ?? false }
	}

	static func concurrentMap<T, U>(_ input: [T], _ transform: (T) -> U) -> [U] {
		guard !input.isEmpty else { return [] }
		var output = [U?](repeating: nil, count: input.count)
		output.withUnsafeMutableBufferPointer { buffer in
			let base = buffer.baseAddress!
			DispatchQueue.concurrentPerform(iterations: input.count) { base[$0] = transform(input[$0]) }
		}
		return output.map { $0! }
	}
}
