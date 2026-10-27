/*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
* ----------------------------------------------------------------------------
*/

import SwiftUI

/**
Sidebar list backed by NSOutlineView. The File Types list holds thousands of rows; an outline view only
builds the visible ones and reloads in one pass, where SwiftUI's List diffs every row on each change.
Group headers toggle on click (Option-click toggles every group); collapsed state lives in AppModel.
*/
@MainActor
struct EntryList: NSViewRepresentable {
	@ObservedObject var model: AppModel

	func makeCoordinator() -> Coordinator { Coordinator() }

	func makeNSView(context: Context) -> NSScrollView {
		let outline = NSOutlineView()
		let column = NSTableColumn(identifier: .init("entry"))
		outline.addTableColumn(column)
		outline.outlineTableColumn = column
		outline.headerView = nil
		// Plain: the source-list and inset styles pad every group row with extra space above it.
		outline.style = .plain
		outline.floatsGroupRows = true
		outline.indentationPerLevel = 0
		outline.usesAutomaticRowHeights = false
		outline.dataSource = context.coordinator
		outline.delegate = context.coordinator
		outline.target = context.coordinator
		outline.action = #selector(Coordinator.clicked(_:))
		context.coordinator.outline = outline

		let scroll = NSScrollView()
		scroll.documentView = outline
		scroll.hasVerticalScroller = true
		scroll.autohidesScrollers = true
		scroll.drawsBackground = false
		return scroll
	}

	func updateNSView(_ scroll: NSScrollView, context: Context) {
		context.coordinator.update(model)
	}

	@MainActor
	final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
		/** NSOutlineView identifies items by reference. */
		final class Group {
			let section: EntrySection
			let rows: [Row]
			init(_ section: EntrySection) {
				self.section = section
				self.rows = section.entries.map(Row.init)
			}
		}
		final class Row {
			let entry: Entry
			init(_ entry: Entry) { self.entry = entry }
		}

		weak var outline: NSOutlineView?
		private var model: AppModel?
		private var version = -1
		private var groups: [Group] = []
		/** Rows shown at the root when the list is not grouped. */
		private var flat: [Row] = []
		private var rowsByID: [String: Row] = [:]
		private var isSyncing = false
		private var shownSelection: String?

		func update(_ model: AppModel) {
			self.model = model
			guard let outline else { return }
			isSyncing = true
			defer { isSyncing = false }
			if version != model.listVersion {
				version = model.listVersion
				let sections = model.sections
				if sections.count == 1, sections[0].title == nil {
					groups = []
					flat = sections[0].entries.map(Row.init)
					rowsByID = Dictionary(flat.map { ($0.entry.id, $0) }, uniquingKeysWith: { a, _ in a })
				} else {
					groups = sections.map(Group.init)
					flat = []
					rowsByID = Dictionary(groups.flatMap(\.rows).map { ($0.entry.id, $0) }, uniquingKeysWith: { a, _ in a })
				}
				outline.reloadData()
				for group in groups where !model.isCollapsed(group.section) {
					outline.expandItem(group)
				}
			}
			syncSelection()
		}

		private func syncSelection() {
			guard let outline, let model else { return }
			guard let id = model.selection, let row = rowsByID[id], outline.row(forItem: row) >= 0 else {
				outline.deselectAll(nil)
				return
			}
			let index = outline.row(forItem: row)
			if outline.selectedRow != index {
				outline.selectRowIndexes([index], byExtendingSelection: false)
			}
			// Only follow selection changes; reloads (e.g. collapsing a group) keep the scroll position.
			if shownSelection != id {
				shownSelection = id
				outline.scrollRowToVisible(index)
			}
		}

		@objc func clicked(_ sender: NSOutlineView) {
			guard let group = sender.item(atRow: sender.clickedRow) as? Group else { return }
			model?.toggle(group.section.id, all: NSEvent.modifierFlags.contains(.option))
		}

		// MARK: Data source

		func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
			switch item {
			case nil: return groups.isEmpty ? flat.count : groups.count
			case let group as Group: return group.rows.count
			default: return 0
			}
		}

		func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
			switch item {
			case nil: return groups.isEmpty ? flat[index] : groups[index]
			case let group as Group: return group.rows[index]
			default: fatalError("Rows have no children")
			}
		}

		func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool { item is Group }

		// MARK: Delegate

		func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool { item is Group }

		func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool { item is Row }

		/** Expansion is driven by AppModel through clicks on the header, never by the outline view itself. */
		func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool { false }

		func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
			item is Group ? 24 : 34
		}

		func outlineViewSelectionDidChange(_ notification: Notification) {
			guard !isSyncing, let outline, let row = outline.item(atRow: outline.selectedRow) as? Row else { return }
			shownSelection = row.entry.id
			model?.selection = row.entry.id
		}

		func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
			item is Group ? GroupRowView(scrollView: outlineView.enclosingScrollView) : EntryRowView()
		}

		func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
			switch item {
			case let group as Group:
				let cell = outlineView.makeView(withIdentifier: GroupCell.identifier, owner: nil) as? GroupCell ?? GroupCell()
				cell.configure(group.section, isCollapsed: model?.isCollapsed(group.section) ?? false)
				return cell
			case let row as Row:
				let cell = outlineView.makeView(withIdentifier: EntryCell.identifier, owner: nil) as? EntryCell ?? EntryCell()
				cell.configure(row.entry)
				return cell
			default:
				return nil
			}
		}
	}
}

/** Icon, title and a secondary line. */
private final class EntryCell: NSTableCellView {
	static let identifier = NSUserInterfaceItemIdentifier("EntryCell")
	private let icon = NSImageView()
	private let title = NSTextField(labelWithString: "")
	private let subtitle = NSTextField(labelWithString: "")

	init() {
		super.init(frame: .zero)
		identifier = Self.identifier
		title.lineBreakMode = .byTruncatingTail
		subtitle.lineBreakMode = .byTruncatingMiddle
		subtitle.font = .preferredFont(forTextStyle: .caption1)
		subtitle.textColor = .secondaryLabelColor
		let text = NSStackView(views: [title, subtitle])
		text.orientation = .vertical
		text.alignment = .leading
		text.spacing = 1
		let stack = NSStackView(views: [icon, text])
		stack.spacing = 8
		stack.translatesAutoresizingMaskIntoConstraints = false
		addSubview(stack)
		NSLayoutConstraint.activate([
			icon.widthAnchor.constraint(equalToConstant: 20),
			icon.heightAnchor.constraint(equalToConstant: 20),
			stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
			stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
			stack.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
		text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
	}

	required init?(coder: NSCoder) { fatalError() }

	@MainActor
	func configure(_ entry: Entry) {
		title.stringValue = entry.title
		subtitle.stringValue = entry.subtitle
		subtitle.isHidden = entry.subtitle.isEmpty
		switch entry.kind {
		case .scheme:
			icon.image = NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)
			icon.contentTintColor = .systemBlue
		case .type:
			icon.image = Icons.type(entry.id)
			icon.contentTintColor = nil
		case .app(let declarations):
			icon.image = Icons.app(declarations.path)
			icon.contentTintColor = nil
		}
	}
}

/** Group header: disclosure chevron, optional app icon, title and row count. */
private final class GroupCell: NSTableCellView {
	static let identifier = NSUserInterfaceItemIdentifier("GroupCell")
	private let chevron = NSImageView()
	private let icon = NSImageView()
	private let title = NSTextField(labelWithString: "")
	private let count = NSTextField(labelWithString: "")

	init() {
		super.init(frame: .zero)
		identifier = Self.identifier
		chevron.symbolConfiguration = .init(pointSize: 9, weight: .semibold)
		chevron.contentTintColor = .secondaryLabelColor
		title.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
		title.textColor = .secondaryLabelColor
		title.lineBreakMode = .byTruncatingTail
		count.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
		count.textColor = .tertiaryLabelColor
		let spacer = NSView()
		spacer.setContentHuggingPriority(.init(1), for: .horizontal)
		let stack = NSStackView(views: [chevron, icon, title, spacer, count])
		stack.spacing = 5
		stack.translatesAutoresizingMaskIntoConstraints = false
		addSubview(stack)
		NSLayoutConstraint.activate([
			chevron.widthAnchor.constraint(equalToConstant: 10),
			icon.widthAnchor.constraint(equalToConstant: 14),
			icon.heightAnchor.constraint(equalToConstant: 14),
			stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
			stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
			stack.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
		title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		toolTip = "Click to collapse or expand; Option-click for all groups"
	}

	required init?(coder: NSCoder) { fatalError() }

	@MainActor
	func configure(_ section: EntrySection, isCollapsed: Bool) {
		chevron.image = NSImage(systemSymbolName: isCollapsed ? "chevron.right" : "chevron.down", accessibilityDescription: nil)
		icon.image = section.app.map { Icons.app($0.path) }
		icon.isHidden = section.app == nil
		title.stringValue = section.title ?? ""
		count.stringValue = "\(section.entries.count)"
	}
}

/**
Row of a group header. It is painted in the list's own background, so it is invisible at rest and hides the
rows scrolling beneath it while floating; a separator appears only while rows actually pass beneath it.
*/
private final class GroupRowView: NSTableRowView {
	private let separator = NSBox()
	/** Held directly: while floating, the row lives in a container outside the scroll view's hierarchy. */
	private weak var scrollView: NSScrollView?
	private var scrollObserver: NSObjectProtocol?

	init(scrollView: NSScrollView?) {
		self.scrollView = scrollView
		super.init(frame: .zero)
		separator.boxType = .separator
		separator.translatesAutoresizingMaskIntoConstraints = false
		addSubview(separator)
		NSLayoutConstraint.activate([
			separator.leadingAnchor.constraint(equalTo: leadingAnchor),
			separator.trailingAnchor.constraint(equalTo: trailingAnchor),
			separator.bottomAnchor.constraint(equalTo: bottomAnchor),
		])
		scrollObserver = scrollView.map { scroll in
			NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in
				MainActor.assumeIsolated { self?.updateSeparator() }
			}
		}
		updateSeparator()
	}

	required init?(coder: NSCoder) { fatalError() }

	deinit { scrollObserver.map(NotificationCenter.default.removeObserver) }

	override var isFloating: Bool {
		didSet { updateSeparator() }
	}

	/** A line only while rows actually pass beneath the header; at rest the first header floats too. */
	private func updateSeparator() {
		separator.isHidden = !(isFloating && (scrollView?.contentView.bounds.minY ?? 0) > 0)
	}

	override func drawBackground(in dirtyRect: NSRect) {
		backgroundColor.setFill()
		dirtyRect.fill()
	}

	override func drawSeparator(in dirtyRect: NSRect) {}
}

/** Row of an entry: the plain style selects edge to edge, so draw the rounded, inset selection of a source list. */
private final class EntryRowView: NSTableRowView {
	override func drawSelection(in dirtyRect: NSRect) {
		(isEmphasized ? NSColor.selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor).setFill()
		NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 1), xRadius: 6, yRadius: 6).fill()
	}
}
