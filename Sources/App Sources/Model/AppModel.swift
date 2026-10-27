/*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
* ----------------------------------------------------------------------------
*/

import AppKit

/** How the File Types list is grouped. */
enum TypeGrouping: String, CaseIterable, Identifiable {
	case none = "None", kind = "Kind", app = "Default App"
	var id: Self { self }
}

/** A titled run of sidebar rows; the title is nil when the list is not grouped. */
struct EntrySection: Identifiable {
	let id: String
	let title: String?
	/** Application whose icon decorates the header, when grouping by default app. */
	let app: AppRef?
	let entries: [Entry]
}

/** UI state of the app: the loaded lists, the search query and the selection of each category. */
@MainActor
final class AppModel: ObservableObject {
	@Published var category: Category = .internet {
		didSet { load(category); refresh() }
	}
	@Published var query = "" {
		didSet { refresh() }
	}
	@Published var typeGrouping: TypeGrouping = .none {
		didSet { refresh() }
	}
	@Published var errorMessage: String?
	/** Current list, filtered, ranked and grouped. */
	@Published private(set) var sections: [EntrySection] = []
	/** Bumped whenever `sections` or the collapsed groups change, so the list view knows to reload. */
	@Published private(set) var listVersion = 0
	/** `sections` flattened, in display order. */
	@Published private(set) var visibleEntries: [Entry] = []
	@Published private var selections: [Category: Entry.ID] = [:]

	private var entries: [Category: [Entry]] = [:]
	private var loading: Set<Category> = []
	/** Default handler of every UTI, for grouping File Types by application. */
	private var typeHandlers: [String: String] = [:]
	private var apps: [String: AppRef] = [:]
	private var collapsed: Set<String> = []

	var isLoading: Bool { entries[category] == nil }

	/** Always a visible entry (or nil when nothing is visible); kept valid by `refresh()`. */
	var selection: Entry.ID? {
		get { selections[category] }
		set { if let newValue { selections[category] = newValue } }
	}

	var selectedEntry: Entry? {
		visibleEntries.first { $0.id == selection }
	}

	private func refresh() {
		let all = entries[category] ?? []
		let q = query.trimmingCharacters(in: .whitespaces)
		let ranked = q.isEmpty ? all : all.enumerated()
			.compactMap { item in item.element.rank(for: q).map { (rank: $0, index: item.offset, entry: item.element) } }
			.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }
			.map(\.entry)
		sections = group(ranked)
		visibleEntries = sections.filter { !isCollapsed($0) }.flatMap(\.entries)
		listVersion += 1
		if !visibleEntries.contains(where: { $0.id == selections[category] }) {
			selections[category] = visibleEntries.first?.id
		}
	}

	private func group(_ entries: [Entry]) -> [EntrySection] {
		guard category == .types, typeGrouping != .none else {
			return [EntrySection(id: "", title: nil, app: nil, entries: entries)]
		}
		switch typeGrouping {
		case .none:
			return []
		case .kind:
			let groups = Dictionary(grouping: entries) { $0.kindGroup ?? "Other" }
			return Catalog.kindOrder.compactMap { kind in
				groups[kind].map { EntrySection(id: kind, title: kind, app: nil, entries: $0) }
			}
		case .app:
			let groups = Dictionary(grouping: entries) { typeHandlers[$0.id]?.lowercased() ?? "" }
			let sections = groups.map { key, entries in
				let app = apps[key]
				return EntrySection(id: key, title: app?.name ?? (key.isEmpty ? "No Default Application" : key), app: app, entries: entries)
			}
			// Apps alphabetically, types without a default last.
			return sections.sorted { a, b in
				if a.id.isEmpty != b.id.isEmpty { return b.id.isEmpty }
				return a.title!.localizedStandardCompare(b.title!) == .orderedAscending
			}
		}
	}

	/** Records the confirmed default of a UTI so grouping by app stays accurate. */
	func defaultChanged(forType identifier: String, to bundleID: String?) {
		guard entries[.types] != nil, typeHandlers[identifier]?.lowercased() != bundleID?.lowercased() else { return }
		typeHandlers[identifier] = bundleID
		if let bundleID, apps[bundleID.lowercased()] == nil { apps[bundleID.lowercased()] = AppRef(bundleID: bundleID) }
		if category == .types && typeGrouping == .app { refresh() }
	}

	func isCollapsed(_ section: EntrySection) -> Bool {
		collapsed.contains(collapseKey(section.id))
	}

	/** Collapses or expands a group; with `all`, every group follows the one toggled. */
	func toggle(_ sectionID: String, all: Bool = false) {
		let collapse = !collapsed.contains(collapseKey(sectionID))
		for key in (all ? sections.map(\.id) : [sectionID]).map(collapseKey) {
			if collapse { collapsed.insert(key) } else { collapsed.remove(key) }
		}
		refresh()
	}

	private func collapseKey(_ sectionID: String) -> String { "\(typeGrouping.rawValue):\(sectionID)" }

	func load(_ category: Category, force: Bool = false) {
		guard force || (entries[category] == nil && !loading.contains(category)) else { return }
		loading.insert(category)
		Task.detached(priority: .userInitiated) {
			let result = Catalog.load(category)
			let handlers = category == .types ? Catalog.defaultHandlers(forTypes: result.map(\.id)) : [:]
			let apps = Dictionary(Set(handlers.values.map { $0.lowercased() }).compactMap { id in AppRef(bundleID: id).map { (id, $0) } },
								  uniquingKeysWith: { a, _ in a })
			await self.finishLoad(category, result, handlers: handlers, apps: apps)
		}
	}

	private func finishLoad(_ category: Category, _ result: [Entry], handlers: [String: String], apps: [String: AppRef]) {
		if category == .types {
			typeHandlers = handlers
			self.apps = apps
		}
		entries[category] = result
		loading.remove(category)
		if category == self.category { refresh() }
	}

	/** Moves the selection within the visible list; used by arrow keys in the search field. */
	func moveSelection(by offset: Int) {
		guard !visibleEntries.isEmpty else { return }
		let current = visibleEntries.firstIndex { $0.id == selection } ?? 0
		selection = visibleEntries[min(max(current + offset, 0), visibleEntries.count - 1)].id
	}

	/** Registers a custom URL scheme, handled by the bundled "do nothing" app until the user picks a real one. */
	func addScheme(_ scheme: String) {
		let scheme = scheme.trimmingCharacters(in: .whitespaces)
		guard !scheme.isEmpty else { return }
		if let error = Catalog.setDefault(AppRef.doNothingID, for: scheme, isScheme: true) {
			errorMessage = error
			return
		}
		selections[.schemes] = scheme
		load(.schemes, force: true)
	}
}
