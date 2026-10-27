/*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
* ----------------------------------------------------------------------------
*/

import SwiftUI
import UniformTypeIdentifiers

/** Shows the detail of the selected entry; each entry gets fresh state through `.id`. */
@MainActor
struct DetailView: View {
	@EnvironmentObject private var model: AppModel

	var body: some View {
		if let entry = model.selectedEntry {
			Group {
				if case .app(let declarations) = entry.kind {
					AppDetail(entry: entry, declarations: declarations)
				} else {
					ContentDetail(entry: entry)
				}
			}
			.id(entry.id)
		} else {
			Text(model.isLoading ? "" : "No Selection")
				.foregroundStyle(.secondary)
		}
	}
}

// MARK: - Scheme / UTI

/** Default-application pickers for a URL scheme or a UTI. */
@MainActor
private struct ContentDetail: View {
	let entry: Entry
	@EnvironmentObject private var model: AppModel
	@State private var states: [Role: HandlerState] = [:]
	/** Roles with a change awaiting confirmation. */
	@State private var pending: Set<Role> = []

	private var isScheme: Bool { entry.kind == .scheme }
	private var roles: [Role] { isScheme ? [.all] : Role.allCases }

	var body: some View {
		Form {
			Section {
				DetailHeader(entry: entry)
			}
			Section {
				picker(for: .all, label: "Open With")
			} footer: {
				Text(isScheme
					 ? "Links using \(entry.id): open in this application."
					 : "Applies to every role, like “Change All…” in Finder’s Get Info.")
			}
			if !isScheme {
				Section("Per-Role Defaults") {
					ForEach([Role.viewer, .editor, .shell]) { picker(for: $0, label: $0.rawValue) }
				}
			}
		}
		.formStyle(.grouped)
		.task { await reload(roles) }
	}

	private func reload(_ roles: [Role]) async {
		let content = entry.id, isScheme = isScheme
		let fresh = await Task.detached(priority: .userInitiated) {
			roles.map { ($0, Catalog.handlers(for: content, isScheme: isScheme, role: $0)) }
		}.value
		for (role, state) in fresh { states[role] = state }
		if !isScheme, let all = states[.all] { model.defaultChanged(forType: content, to: all.current) }
	}

	@ViewBuilder
	private func picker(for role: Role, label: String) -> some View {
		if pending.contains(role) || pending.contains(.all) {
			LabeledContent(label) { WaitingLabel() }
		} else if let state = states[role] {
			HandlerPicker(label: label, state: state) { choose($0, role: role) }
		} else {
			LabeledContent(label) { ProgressView().controlSize(.small) }
		}
	}

	private func choose(_ bundleID: String, role: Role) {
		if let error = Catalog.setDefault(bundleID, for: entry.id, isScheme: isScheme, role: role) {
			model.errorMessage = error
			return
		}
		pending.insert(role)
		let content = entry.id, isScheme = isScheme
		Task {
			let result = await Catalog.settledDefault(for: content, isScheme: isScheme, role: role, target: bundleID)
			// Re-read every role: "All Roles" changes them all, and a declined prompt changes none.
			await reload(roles)
			pending.remove(role)
			if !result.prompted, result.handler?.caseInsensitiveCompare(bundleID) != .orderedSame {
				model.errorMessage = "Launch Services did not apply the change for \(content)."
			}
		}
	}
}

/** A menu of candidate handlers plus "Do Nothing" and "Other…". */
@MainActor
private struct HandlerPicker: View {
	let label: String
	let state: HandlerState
	let onChoose: (String) -> Void

	private static let otherTag = "\u{0}other"

	private var currentTag: String {
		guard let current = state.current else { return "" }
		guard !state.isCurrent(AppRef.doNothingID) else { return AppRef.doNothingID }
		return state.candidates.first { $0.id.caseInsensitiveCompare(current) == .orderedSame }?.id ?? ""
	}

	var body: some View {
		Picker(label, selection: Binding(get: { currentTag }, set: { select($0) })) {
			if currentTag.isEmpty {
				Text("None").tag("")
			}
			ForEach(state.candidates) { app in
				Label { Text(app.name) } icon: { Image(nsImage: Icons.menuApp(app.path)) }
					.tag(app.id)
					.labelStyle(.titleAndIcon)
			}
			Divider()
			Text("Do Nothing").tag(AppRef.doNothingID)
			Text("Other…").tag(Self.otherTag)
		}
	}

	private func select(_ tag: String) {
		guard tag != currentTag, !tag.isEmpty else { return }
		if tag == Self.otherTag {
			let panel = NSOpenPanel()
			panel.allowedContentTypes = [.application]
			panel.directoryURL = URL(fileURLWithPath: "/Applications")
			panel.prompt = "Choose"
			guard panel.runModal() == .OK, let url = panel.url else { return }
			guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
			onChoose(bundleID)
		} else {
			onChoose(tag)
		}
	}
}

// MARK: - Application

/** One scheme or UTI an application declares, with its current handlers. */
private struct Claim: Identifiable {
	let id: String
	let title: String
	let subtitle: String
	let isScheme: Bool
	let handlers: HandlerState
	let isDefault: Bool

	var key: String { (isScheme ? "scheme:" : "type:") + id }
}

/** Everything an application declares, with one-click "Make Default". */
@MainActor
private struct AppDetail: View {
	let entry: Entry
	let declarations: AppDeclarations
	@EnvironmentObject private var model: AppModel
	@State private var claims: [Claim]?
	/** Claims with a change awaiting confirmation. */
	@State private var pending: Set<String> = []

	var body: some View {
		Form {
			Section {
				DetailHeader(entry: entry)
				LabeledContent("Location") {
					HStack(spacing: 4) {
						Text(declarations.path)
							.lineLimit(1)
							.truncationMode(.middle)
							.textSelection(.enabled)
						Button {
							NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: declarations.path)])
						} label: { Image(systemName: "magnifyingglass.circle.fill") }
							.buttonStyle(.borderless)
							.help("Reveal in Finder")
					}
				}
			}
			if let claims {
				claimSection("URL Schemes", claims.filter(\.isScheme))
				claimSection("File Types", claims.filter { !$0.isScheme })
			} else {
				Section { ProgressView().frame(maxWidth: .infinity) }
			}
		}
		.formStyle(.grouped)
		.task {
			let bundleID = entry.id, declarations = declarations
			claims = await Task.detached(priority: .userInitiated) { Self.loadClaims(bundleID, declarations) }.value
		}
	}

	@ViewBuilder
	private func claimSection(_ title: String, _ items: [Claim]) -> some View {
		if !items.isEmpty {
			Section("\(title) (\(items.filter(\.isDefault).count) of \(items.count) default)") {
				ForEach(items) { claim in
					ClaimRow(claim: claim, appID: entry.id, isPending: pending.contains(claim.key)) { choose($0, for: claim) }
				}
			}
		}
	}

	private func choose(_ bundleID: String, for claim: Claim) {
		if let error = Catalog.setDefault(bundleID, for: claim.id, isScheme: claim.isScheme) {
			model.errorMessage = error
			return
		}
		pending.insert(claim.key)
		let appID = entry.id
		Task {
			let result = await Catalog.settledDefault(for: claim.id, isScheme: claim.isScheme, target: bundleID)
			let handlers = await Task.detached(priority: .userInitiated) {
				Catalog.handlers(for: claim.id, isScheme: claim.isScheme)
			}.value
			claims = claims?.map { old in
				guard old.key == claim.key else { return old }
				return Claim(id: old.id, title: old.title, subtitle: old.subtitle, isScheme: old.isScheme,
							 handlers: handlers, isDefault: handlers.isCurrent(appID))
			}
			pending.remove(claim.key)
			if !claim.isScheme { model.defaultChanged(forType: claim.id, to: handlers.current) }
			if !result.prompted, !handlers.isCurrent(bundleID) {
				model.errorMessage = "Launch Services did not apply the change for \(claim.id)."
			}
		}
	}

	private nonisolated static func loadClaims(_ bundleID: String, _ declarations: AppDeclarations) -> [Claim] {
		let schemes = Catalog.concurrentMap(declarations.schemes) { scheme -> Claim in
			let handlers = Catalog.handlers(for: scheme, isScheme: true)
			return Claim(id: scheme, title: "\(scheme):", subtitle: LSWrappers.Schemes.getNameForScheme(scheme) ?? "",
						 isScheme: true, handlers: handlers, isDefault: handlers.isCurrent(bundleID))
		}
		let types = Catalog.concurrentMap(declarations.types) { identifier -> Claim in
			let type = UTType(identifier)
			let extensions = (type?.tags[.filenameExtension] ?? []).map { ".\($0)" }.joined(separator: " ")
			let handlers = Catalog.handlers(for: identifier, isScheme: false)
			return Claim(id: identifier, title: type?.localizedDescription ?? identifier,
						 subtitle: extensions.isEmpty ? identifier : "\(identifier) · \(extensions)",
						 isScheme: false, handlers: handlers, isDefault: handlers.isCurrent(bundleID))
		}.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
		return schemes + types
	}
}

/**
A declared scheme or UTI. Launch Services cannot clear a default, only replace it, so a row this app
already owns offers a menu to hand it to another application; other rows offer "Make Default".
*/
@MainActor
private struct ClaimRow: View {
	let claim: Claim
	let appID: String
	let isPending: Bool
	let onChoose: (String) -> Void

	private var currentName: String? {
		guard let current = claim.handlers.current else { return nil }
		if claim.handlers.isCurrent(AppRef.doNothingID) { return "Do Nothing" }
		return claim.handlers.candidates.first { $0.id.caseInsensitiveCompare(current) == .orderedSame }?.name ?? current
	}

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: claim.isDefault ? "checkmark.circle.fill" : "circle")
				.foregroundStyle(claim.isDefault ? Color.green : Color.secondary.opacity(0.5))
				.help(claim.isDefault ? "This application is the default" : "Another application is the default")
			VStack(alignment: .leading, spacing: 1) {
				Text(claim.title).lineLimit(1)
				Text(claim.subtitle)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
					.textSelection(.enabled)
				if !claim.isDefault {
					Text(currentName.map { "Opens with \($0)" } ?? "No default application")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			Spacer(minLength: 8)
			if isPending {
				WaitingLabel()
			} else if claim.isDefault {
				HandlerPicker(label: "Default Application", state: claim.handlers, onChoose: onChoose)
					.labelsHidden()
					.fixedSize()
					.help("Choose another application")
			} else {
				Button("Make Default") { onChoose(appID) }
					.controlSize(.small)
			}
		}
	}
}

// MARK: - Shared

/** Shown while a change waits for Launch Services, or for the user to answer its confirmation prompt. */
@MainActor
private struct WaitingLabel: View {
	var body: some View {
		HStack(spacing: 6) {
			ProgressView().controlSize(.small)
			Text("Waiting for confirmation…").foregroundStyle(.secondary)
		}
	}
}

@MainActor
private struct DetailHeader: View {
	let entry: Entry

	private var lines: [String] {
		switch entry.kind {
		case .scheme:
			return [entry.title == entry.id ? "" : entry.title, entry.subtitle].filter { !$0.isEmpty && $0 != "\(entry.id):" }
		case .type:
			return [entry.id, entry.extensions.map { ".\($0)" }.joined(separator: "  ")].filter { !$0.isEmpty }
		case .app(let declarations):
			return [entry.id, declarations.version.map { "Version \($0)" } ?? ""].filter { !$0.isEmpty }
		}
	}

	var body: some View {
		HStack(spacing: 12) {
			EntryIcon(entry: entry)
			VStack(alignment: .leading, spacing: 2) {
				Text(entry.kind == .scheme ? "\(entry.id):" : entry.title)
					.font(.title2.weight(.semibold))
					.lineLimit(2)
				ForEach(lines, id: \.self) {
					Text($0).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
				}
			}
			.textSelection(.enabled)
		}
		.padding(.vertical, 4)
	}
}

@MainActor
struct EntryIcon: View {
	let entry: Entry
	var size: CGFloat {
		switch entry.kind {
		case .scheme, .type: 48
		case .app: 64
		}
	}

	var body: some View {
		switch entry.kind {
		case .scheme:
			Image(systemName: "link.circle.fill")
				.resizable()
				.foregroundStyle(.blue)
				.frame(width: size * 0.85, height: size * 0.85)
				.frame(width: size, height: size)
		case .type:
			Image(nsImage: Icons.type(entry.id))
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(maxHeight: size)
		case .app(let declarations):
			Image(nsImage: Icons.app(declarations.path))
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(maxHeight: size)
		}
	}
}

/** Icon lookups are not free and the lists are long, so results are cached per path/UTI. */
@MainActor
enum Icons {
	private static let cache = NSCache<NSString, NSImage>()

	static func app(_ path: String?) -> NSImage {
		cached("app:\(path ?? "")") { loadApp(path) }
	}

	/**
	Menus draw an image at its point size, and `icon(forFile:)` starts at 32pt. Setting the size of a freshly
	loaded icon to 16pt makes the menu pick the icon's own 16pt artwork for each backing scale, as Finder does.
	*/
	static func menuApp(_ path: String?) -> NSImage {
		cached("menu:\(path ?? "")") {
			let icon = loadApp(path)
			icon.size = NSSize(width: 16, height: 16)
			return icon
		}
	}

	static func type(_ identifier: String) -> NSImage {
		cached("uti:\(identifier)") {
			NSWorkspace.shared.icon(for: UTType(identifier) ?? .data)
		}
	}

	/** Every call returns a new image, so resizing one never affects another cache entry. */
	private static func loadApp(_ path: String?) -> NSImage {
		path.map { NSWorkspace.shared.icon(forFile: $0) } ?? NSWorkspace.shared.icon(for: .application)
	}

	private static func cached(_ key: String, make: () -> NSImage) -> NSImage {
		if let image = cache.object(forKey: key as NSString) { return image }
		let image = make()
		cache.setObject(image, forKey: key as NSString)
		return image
	}
}
