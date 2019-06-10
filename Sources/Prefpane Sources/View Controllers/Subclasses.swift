/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

extension DRYView {
    /** Bridge required to make currentTab really dependent on the selectedTabViewItemIndex */
    @objc weak var tabViewController: SWDATabViewController? { return ControllersRef.sharedInstance.tabViewController }
    
    /** Reference to the currently selected TabViewItem */
    @objc dynamic var currentTab: String? {
        if let selectedTab = ControllersRef.sharedInstance.tabViewController?.currentTab {
            return selectedTab.label
        }
        else { return nil }
    }
    
    /** Open Finder and Reveal the currently selected Application. */
    @IBAction func revealAppInFinder(_ sender: NSButton) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:sender.title)])
    }
    
    /** Determines whether to show a Description in the Detail View */
    @objc var showDescriptionBool: NSNumber {
        guard (self.currentTab != nil) else { return NSNumber(booleanLiteral:true) }
        return NSNumber(booleanLiteral:ControllersRef.TabData.shouldShowDescription)
    }
    
    /** Determines whether to show a path and Reveal In Finder button */
    @objc var showPathBool: NSNumber {
        guard (self.currentTab != nil) else { return NSNumber(booleanLiteral:false) }
        return NSNumber(booleanLiteral:ControllersRef.TabData.shouldShowAppPath)
    }
    
    /** The only tab where an "Add" button is at all meaningful is the URI Schemes. */
    @objc var showAddRemoveBool: NSNumber {
        guard (self.currentTab != nil) else { return NSNumber(booleanLiteral:false) }
        return NSNumber(booleanLiteral:ControllersRef.TabData.shouldShowAddRemove)
    }
    
    /** Determines whether to ahow a list of file extensions associated with a given UTI. */
    @objc var showFileExtensionsBool: NSNumber {
        guard (self.currentTab != nil) else { return NSNumber(booleanLiteral:false) }
        return NSNumber(booleanLiteral:ControllersRef.TabData.shouldShowFileExts)
    }
    
    @objc class func keyPathsForValuesAffectingShowDescriptionBool() -> Set<String> {
        return Set([#keyPath(currentTab), #keyPath(inspectedObject)])
    }
    @objc class func keyPathsForValuesAffectingShowPathBool() -> Set<String> {
        return Set([#keyPath(currentTab), #keyPath(inspectedObject)])
    }
    @objc class func keyPathsForValuesAffectingShowAddRemoveBool() -> Set<String> {
        return Set([#keyPath(currentTab), #keyPath(inspectedObject)])
    }
    @objc class func keyPathsForValuesAffectingShowFileExtensionsBool() -> Set<String> {
        return Set([#keyPath(currentTab), #keyPath(inspectedObject)])
    }
    @objc class func keyPathsForValuesAffectingCurrentTab() -> Set<String> {
        return Set(["tabViewController.selectedTabViewItemIndex"])
    }
}

/** NSView subclass used to implement automatic sorting of the NSTableView. */
class SWDATableView: NSView {
    
    @IBOutlet weak var arrayController: NSArrayController?
    @IBOutlet weak var tableView: NSTableView?
    
    let defaultSortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]
    override func awakeFromNib() {
        if let ac = arrayController {
            if let tableView = tableView {
                ac.bind(NSBindingName(rawValue: "sortDescriptors"), to:tableView, withKeyPath: "sortDescriptors", options:nil)
                tableView.sortDescriptors = defaultSortDescriptors
                tableView.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
                self.tableView?.becomeFirstResponder()
            }
        }
    }
}

/** By subclassing (instead of extending) DRYView for this, we make sure variables such as the contentArray and other possibly-work-intensive code is only executed on instances of the tab and not also in the detail view.*/
class SWDATabTemplate: DRYView {
    @IBOutlet weak var progressAlert: ProgressAlert?
    @IBOutlet weak var titleView: NSView?
    @IBOutlet weak var customNewScheme: NSTextField?
    @IBOutlet var arrayController: NSArrayController!
    
    @IBOutlet var tableView: NSTableView!
    
    /** Let's save selected item for each tab, update selectionIndex with the current value of our selection when our selection would be replaced with an empty or invalid one. */
    @objc var tableIndexes = NSIndexSet(index: 0)
        {
        willSet {
            if (newValue.count < 1) { self.selectionIndex = self.tableIndexes.firstIndex }
        }
    }
    
    /** Add a custom URI Scheme and assign our dummy app as the default handler. In practice this should almost never be necessary but sometimes Launch Services move in mysterious ways. */
    @IBAction func addCustomScheme(_ sender: NSButton) {
        guard (customNewScheme?.stringValue != nil) && (customNewScheme?.stringValue != "") else { return }
        let result = LSWrappers.Schemes.setDefaultHandler(customNewScheme!.stringValue, "cl.fail.lordkamina.ThisAppDoesNothing")
        if (result == 0) {
            SWDAHandlersModel.setValue(nil, forKey: "allSchemes")
            self.setValue(nil, forKey: "contentArrayStore")
        }
			try! displayAlert(error: result, arg1: "Do Nothing", arg2: customNewScheme!.stringValue)
            return
        }
    
    /** Identifies which tab the current instance belongs to. */
    var tabIndex: Int? = -1
    
    /** This is where we'll store our selection indexes when switching tabs. */
    var selectionIndex: Int? = nil
    
    /** Backing Store for the list of items on each tab. */
    @objc var contentArrayStore: Array<AnyObject>?
    
    /** Check whether contentArrayStore holds anything; return that if it does or populate it asynchronously if it doesn't. */
    @objc var contentArray: Array<AnyObject>? {
        guard self.nibName == "SWDAPrefpaneTabTemplate" else { return [] }
        if (self.tabIndex == ControllersRef.sharedInstance.tabViewController?.selectedTabViewItemIndex) {
            if (self.contentArrayStore == nil) {
                ControllersRef.TabData.getContentArray(for: self)
                return nil
            }
            else {
                if let content = self.value(forKey:"contentArrayStore") as? Array<AnyObject> {
                    defer { self.tableView?.becomeFirstResponder() }
                    return content
                }
                else { return nil }
            }
        }
        else {
            return nil
        }
    }
    
    @objc class func keyPathsForValuesAffectingContentArray() -> Set<String> {
        return Set([#keyPath(currentTab), #keyPath(contentArrayStore)])
    }
    
    @objc class func keyPathsForValuesAffectingContentArrayStore() -> Set<String> {
        return Set([#keyPath(currentTab)])
    }
}

/** NSTabView subclass, initializes instances of the canned tabs, builds the tabView and handles saving data such as selection indexes between multiple tabs. */
class SWDATabViewController: NSTabViewController {
    /** KVO context */
    private let tabViewKVOContext = UnsafeMutableRawPointer(bitPattern: 1)
    
    /** Return an instance of the currently selected NSTabViewItem */
    var currentTab: NSTabViewItem? {
        get {
            guard self.isViewLoaded != false else { return nil }
            let index = self.selectedTabViewItemIndex
            guard index != -1 else { return nil }
            let tab = self.tabView.tabViewItem(at: index)
            return tab
        }
    }
    
    /** Preserve selection indexes when switching tabs. */
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard (context == tabViewKVOContext) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if (tabViewKVOContext == context) {
            guard (change![.oldKey]! as! Int != -1) else { return }
            let oldTab = self.children[change![.oldKey]! as! Int].view as! SWDATabTemplate
            let newTab = self.children[change![.newKey]! as! Int].view as! SWDATabTemplate
            
            if (newTab.selectionIndex != 0) {
                newTab.setValue(NSIndexSet(index: newTab.selectionIndex!), forKey: "tableIndexes")
            }
            else {
                newTab.setValue(NSIndexSet(index:0), forKey: "tableIndexes")
            }
            newTab.tableView?.scrollRowToVisible(newTab.arrayController.selectionIndex)
        }
    }
    /** Initialize the NSTabView, create the tabs and assign their NIB. */
    override func viewDidLoad() {
        self.tabView.tabViewType = .topTabsBezelBorder
        addObserver(self, forKeyPath: #keyPath(selectedTabViewItemIndex), options: [.old, .new], context: tabViewKVOContext)
        let tabViewController = self
        self.tabView.translatesAutoresizingMaskIntoConstraints = false
		let leading = NSLayoutConstraint(item: ControllersRef.sharedInstance.theMainView!, attribute: .leading    , relatedBy: .equal, toItem: self.tabView, attribute: .leading  , multiplier: 1, constant: -20)
        leading.identifier = "TabView Leading"
		let trailing = NSLayoutConstraint(item: ControllersRef.sharedInstance.theMainView!, attribute: .trailing    , relatedBy: .equal, toItem: self.tabView, attribute: .trailing  , multiplier: 1, constant: 20)
        trailing.identifier = "TabView Trailng"
		let centerX = NSLayoutConstraint(item: ControllersRef.sharedInstance.theMainView!, attribute: .centerX    , relatedBy: .equal, toItem: self.tabView, attribute: .centerX  , multiplier: 1, constant: 0)
        centerX.identifier = "TabView CenterX"
		let top = NSLayoutConstraint(item: ControllersRef.sharedInstance.theMainView!, attribute: .top    , relatedBy: .equal, toItem: self.tabView, attribute: .top  , multiplier: 1, constant: -20)
        top.identifier = "TabView Top"
		let bottom = NSLayoutConstraint(item: ControllersRef.sharedInstance.theMainView!, attribute: .bottom    , relatedBy: .equal, toItem: self.tabView, attribute: .bottom  , multiplier: 1, constant: 10)
        bottom.identifier = "TabView Bottom"
        let tabs = ["Internet", "URI Schemes", "Uniform Type Identifiers", "Applications"]
        
        ControllersRef.sharedInstance.theMainView.addConstraints([centerX, leading, trailing, bottom, top])
        
        for tab in tabs {
            let newTabVC = NSViewController.init()
            newTabVC.view = SWDATabTemplate.init()
            let index = tabs.firstIndex(of: tab)
            (newTabVC.view as! SWDATabTemplate).tabIndex = (index != nil) ? index!  : nil
            (newTabVC.view as! SWDATabTemplate).nibName = "SWDAPrefpaneTabTemplate"
            
            tabViewController.addChild(newTabVC)
            
            let newTab = tabViewController.tabViewItem(for: newTabVC)!
            newTab.label = tab
        }
    }
    
    class func keyPathsForValuesAffectingCurrentTab() -> Set<String> {
        return Set([#keyPath(selectedTabViewItemIndex)])
    }
    
    deinit {
        if let _ = tabViewKVOContext {
            removeObserver(self, forKeyPath: #keyPath(selectedTabViewItemIndex), context: tabViewKVOContext)
        }
    }
}

/**
 NSTreeController sub-class that acts mostly as a bridge between the DRYViews and a couple Bindings.
 Single outlineView delegate function implemented obeying strictly to a cosmetic issue.
 */
class SWDATreeController: NSTreeController, NSOutlineViewDelegate {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    @IBOutlet weak var outlineView: NSOutlineView?
    @IBOutlet weak var dryView: DRYView?
    
    /**
     Return true if "Applications" is the currently selected tab.
     */
    @objc var showPathBool: NSNumber {
        if let view = dryView {
            return view.value(forKey:"showPathBool") as! NSNumber
        }
        else { return NSNumber(booleanLiteral: false) }
    }
    /** Expand tree items by default.
     */
    override var content: Any? {
        didSet {
            self.outlineView?.expandItem(nil, expandChildren: true)
        }
    }
    /**
     Determines whether to show the disclosure button for a group row depending on the selected tab and its place in the hierarchy.
     */
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        let row = item as! NSTreeNode
        if let object = row.representedObject as? SWDATreeRow {
            if object.rowLevel == .role { return false }
            else {
                if (object.rowLevel == .header) {
                    if let isItRole = SourceListRoleTypes(rawValue: object.rowTitle) {
                        return false
                    }
                    else { return true }
                }
                if let children = row.children {
                    return children.count > 0
                }
                else { return false }
            }
        }
        else { return false }
    }
}

@IBDesignable
class HyperlinkTextField: NSTextField {
    @IBInspectable var href: String = ""
    override func awakeFromNib() {
        super.awakeFromNib()
        let attributes: [NSAttributedString.Key:AnyObject] = [
            NSAttributedString.Key.foregroundColor: NSColor.blue,
            NSAttributedString.Key.backgroundColor: NSColor.clear,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue as AnyObject
        ]
        self.attributedStringValue = NSAttributedString(string: self.stringValue, attributes: attributes)
    }
    
    override func mouseDown(with event: NSEvent) {
        NSWorkspace.shared.open(URL(string: self.href)!)
    }
    convenience init (frame: NSRect, url: String, text: String? = nil) {
        self.init(frame:frame)
        self.drawsBackground = false
        self.isEditable = false
        self.isBezeled = false
        if let text = text {
        self.stringValue = text
        }
        else { self.stringValue = url }
        self.href = url
        self.awakeFromNib()
    }
}
