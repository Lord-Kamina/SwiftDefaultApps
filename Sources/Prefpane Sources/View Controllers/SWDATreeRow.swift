/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

/** Represent an instance of a kind of Content (UTI/URL) and a valid associated application in a given role. */
class SWDAContentHandler: NSObject {
    var content: NSObjectProtocol & SWDAContentProtocol
    var appName: String = "None"
    
    var application: SWDAApplicationInfo? {
        if let info = SWDAApplicationInfo(self.appName) {
            return info
        }
        else { return nil }
    }
    var roleMask: SourceListRoleTypes?
    init(_ content: NSObjectProtocol & SWDAContentProtocol, appName: String, role: SourceListRoleTypes?) {
        self.content = content
        self.appName = appName
        if let role = role {
            self.roleMask = role
        }
        super.init()
    }
}

/** Our NSObject sub-class that represents a ContentHandler, foundation of the Detail Outline view and as such responsible for most of the heavy lifting */
internal class SWDATreeRow:NSObject {
    
    /** Used chiefly for cosmetic purposes in presenting and styling the rows. */
    enum levels {
        case header, role, handler
    }
    
    /** Required functionality for our NSTreeView. */
    weak var parentNode: SWDATreeRow?
    @objc var children: [SWDATreeRow] = []
    @objc var count: Int { return children.count }
    @objc var isLeaf: Bool { return children.count < 1}
    
    
    /** Dirty trick to avoid subclassing NSOutlineView. */
    @objc var shouldFauxIndent: Bool {
        return self.rowLevel == .handler
    }
    
    /** Actually determine what kind of row we are. */
    var rowLevel: levels {
        if (self.parentNode == nil) { return .header }
        else {
            if (self.children.count < 1) { return .handler }
            else { return .role }
        }
    }
    
    /** Reference to the System Font; not strictly needed but in case it changes in the future, this way we only actually need to modify it in one place. */
    var baseFont: NSFont = NSFont.systemFont(ofSize:0)
    
    /** Bindings-compatible determination of the font to use. */
    @objc var rowFont: NSFont? {
        switch self.rowLevel {
        case .header: return self.baseFont.smallCaps()
        case .role: return self.baseFont.bold()
        default: return self.baseFont
        }
    }
    /** Show header rows in a different color. */
    @objc var textColor: NSColor? {
        switch self.rowLevel {
        case .header: return NSColor.headerColor
        default: return NSColor.controlTextColor
        }
    }
    
    /** What the Tree Row will actually display as a label. */
    @objc var rowTitle: String
    
    /** Content and associated application. Optional to account for dummy rows like Headers. */
    var rowContent: SWDAContentHandler?
    var roleMask: SourceListRoleTypes?
    
    @objc lazy var appIcon: NSImage? = { return self.rowContent?.application?.appIcon }()
    
    /** Binding-compatible determination used exclusively for SWDATreeRows in the Applications tab. Returns true if the currently selected application is the default handler for the content represented by this row. It's only enabled when its state is off, since in practice it's not actually possible to remove handlers from LaunchServices. Rather, the service takes care of its own clean-up if it detects an UTI or URL Scheme does not have any valid handlers. */
    @objc var isHandlingContent: Bool {
        get {
            guard (ControllersRef.sharedInstance.tabViewController!.currentTab?.label == "Applications") else { return false }
            guard (self.rowContent != nil) else { return false }
            let contentType = self.rowContent?.content.contentType
            guard (contentType != .Application) else { return false }
            let defaultHandler = (contentType == .URI) ? LSWrappers.Schemes.copyDefaultHandler(self.rowTitle, asPath: false) : LSWrappers.UTType.copyDefaultHandler(self.rowTitle, inRoles: LSRolesMask(from:self.roleMask!), asPath: false)
            return self.rowContent?.application?.appBundleID?.lowercased() == defaultHandler?.lowercased()
        }
        set {
            guard (ControllersRef.sharedInstance.tabViewController!.currentTab?.label == "Applications") else { return }
            if let content = (self.rowContent?.content as? SWDAContentItem) {
                let contentName = content.contentName
                let type = content.contentType
                var status = OSStatus()
                
                if let bundleID = self.rowContent?.application?.appBundleID {
                    status = (type == .URL) ? LSWrappers.Schemes.setDefaultHandler(contentName, bundleID) : LSWrappers.UTType.setDefaultHandler(contentName, bundleID, LSRolesMask(from:self.roleMask!))
                    let alert = NSAlert()
                    alert.informativeText = (status == 0) ? "Succesfully changed default handler for \(self.rowTitle) to \(self.rowContent?.application?.displayName ?? "Invalid App")" : LSWrappers.LSErrors(value: status).print(argument: (app: (self.rowContent?.application?.displayName)!, content: self.rowTitle))
                    alert.icon = ControllersRef.appIcon
                    alert.messageText = (status == 0) ? "Success" : "Error"
                    alert.alertStyle = (status == 0) ? .informational : .critical
                    alert.addButton(withTitle: "OK")
                    DispatchQueue.main.async {
                        if let parent = self.parentNode {
                            for node in parent.children {
                                node.willChangeValue(forKey: "isDefaultHandler")
                                node.didChangeValue(forKey: "isDefaultHandler")
                            }
                        }
                        DispatchQueue.main.async {
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }
    
    /** Binding-compatible determination used in every tab except for Applications. Returns true if the application represented by the current row is the default handler for the selected content type. Allows "Other" to specify apps that aren't detected as valid handlers for whatever reason. Note that setting something to be handled by "Other" will not _actually_ work unless the application's Info.plist adequately declares association with that content. */
    @objc var isDefaultHandler: Bool {
        get {
            if let content = (self.rowContent?.content as? SWDAContentItem) {
                var handler: String?
                switch content.contentType {
                case .Application: return false
                case .UTI: handler = LSWrappers.UTType.copyDefaultHandler(content.contentName, inRoles:LSRolesMask(from:self.roleMask!), asPath: false)
                case .URI: handler = LSWrappers.Schemes.copyDefaultHandler(content.contentName, asPath: false)
                }
                guard (handler != nil) else { return false }
                return (handler?.lowercased() == rowContent?.application?.appBundleID?.lowercased())
            }
            else { return false }
        }
        set {
            if let content = (self.rowContent?.content as? SWDAContentItem) {
                let contentName = content.contentName
                let type = content.contentType
                var status = OSStatus()
                if let bundleID = self.rowContent?.application?.appBundleID {
                    
                    status = (type == .URL) ? LSWrappers.Schemes.setDefaultHandler(contentName, bundleID) : LSWrappers.UTType.setDefaultHandler(contentName, bundleID, LSRolesMask(from:self.roleMask!))
                    let alert = NSAlert()
                    alert.informativeText = (status == 0) ? "Succesfully changed default handler for \(content.displayName) to \(self.rowTitle)" : LSWrappers.LSErrors(value: status).print(argument: (app: self.rowTitle, content: contentName))
                    alert.icon = ControllersRef.appIcon
                    alert.messageText = (status == 0) ? "Success" : "Error"
                    alert.alertStyle = (status == 0) ? .informational : .critical
                    alert.addButton(withTitle: "OK")
                    DispatchQueue.main.async {
                        if let parent = self.parentNode {
                            for node in parent.children {
                                node.willChangeValue(forKey: "isDefaultHandler")
                                node.didChangeValue(forKey: "isDefaultHandler")
                            }
                        }
                        DispatchQueue.main.async {
                            alert.runModal()
                        }
                    }
                }
                else if (self.rowTitle == "Other...") {
                    let openpanel = NSOpenPanel()
                    openpanel.treatsFilePackagesAsDirectories = false
                    openpanel.allowsMultipleSelection = false
                    openpanel.canChooseDirectories = false
                    openpanel.resolvesAliases = true
                    openpanel.canChooseFiles = true
                    openpanel.allowedFileTypes = ["app"]
                    openpanel.allowsOtherFileTypes = true
                    openpanel.title = "Choose a default application for: \(content.displayName)"
                    openpanel.prompt = "Add"
                    openpanel.runModal()
                    if !openpanel.urls.isEmpty {
                        let handler = SWDAContentHandler(content, appName:openpanel.urls[0].path, role:self.roleMask)
                        if let tempName = handler.application?.displayName {
                            let displayName = (tempName.lowercased().range(of:".app") != nil) ? tempName : "\(tempName).app"
                            let row = SWDATreeRow(displayName, content: handler)
                            self.parentNode?.addChild(row)
                            row.isDefaultHandler = true
                        }
                        else {
                            let displayName = FileManager.default.displayName(atPath: openpanel.urls[0].path)
                            let row = SWDATreeRow(displayName, content: handler)
                            self.parentNode?.addChild(row)
                            row.isDefaultHandler = true
                        }
                        self.parentNode?.children.sort(){($0.rowTitle < $1.rowTitle) && ($0.rowTitle != "Other..." && $0.rowTitle != "Do Nothing")}
                        
                        self.parentNode?.willChangeValue(forKey: "children")
                        self.parentNode?.didChangeValue(forKey: "children")
                    }
                }
            }
        }
    }
    
    /**
     Add a Child Row
     - Parameter child: An instance of SWDATreeRow to be added as a child.
     */
    func addChild (_ child: SWDATreeRow) {
        guard (self.children.firstIndex(of: child) == nil) else { return }
        child.parentNode = self
        self.children.append(child)
    }
    
    /**
     Add all the children of a given SWDATreeRow as children of this instance.
     - Parameter row: An instance of SWDATreeRow to take children from.
     - Note: This is only used to hide the "Viewer" role from URL Schemes, since handler roles are not currently implemented for URL Handlers.
     */
    func addChildren (of row: SWDATreeRow) {
        for child in row.children {
            guard (self.children.firstIndex(of: child) == nil) else { return }
            child.parentNode = self
            self.children.append(child)
        }
    }
    
    init(_ name: String, content: SWDAContentHandler? = nil) {
        self.rowTitle = name
        if let content = content {
            self.rowContent = content
            self.roleMask = content.roleMask
        }
        super.init()
    }
}
