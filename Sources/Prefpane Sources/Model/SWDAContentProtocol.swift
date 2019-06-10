/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

/** Abstract protocol adopted by SWDAContentItem and SWDAApplicationItem, which define the appropriate classes to populate the NSTableView with. */
internal protocol SWDAContentProtocol: class {
    var contentType: SWDAContentType { get set }
    var contentName: String { get set }
    var contentDescription: String { get set }
    var displayName: String { get set }
    var contentHandlers: [SWDATreeRow] { get set }
    func getDescription() -> String
    var appIcon: NSImage? { get }
    var getExtensions: String { get }
}

/** The main class adopting SWDAContentProtocol, represents either a UTI or an URL; it's name, associated handlers, description in the case of URI Schemes and associated file-extensions in the case of UTIs.*/
class SWDAContentItem: NSObject, SWDAContentProtocol {
    
    /** Generates the NSTreeView displaying all the handlers associated to this content type. Results are sorted alphabetically, with the exception of the special "Other..." and "Do Nothing" entries. */
    @objc lazy var contentHandlers: [SWDATreeRow] = {
        var roles: [SWDATreeRow] = []
        var rolesArray: [SourceListRoleTypes] = []
        switch self.contentType {
        case .UTI:
            rolesArray = [.Viewer, .Editor, .Shell]
        case .URI:
            rolesArray = [.Viewer]
        case .Application: return []
        }
        for role in rolesArray {
            var tempChildren: [SWDATreeRow] = []
            let category = SWDATreeRow(role.rawValue)
            if let handlerAppNames = (self.contentType == .URI) ? LSWrappers.Schemes.copyAllHandlers(self.contentName, asPath:true) : LSWrappers.UTType.copyAllHandlers(self.contentName, inRoles: LSRolesMask(from: role), asPath:true) {
                for app in handlerAppNames {
                    let handler = SWDAContentHandler(self, appName:app, role:role)
                    if let tempName = handler.application?.displayName {
                        let displayName = (tempName.lowercased().range(of:".app") != nil) ? tempName : "\(tempName).app"
                        if (displayName != "Do Nothing.app") {
                            let row = SWDATreeRow(displayName, content: handler)
                            category.addChild(row)
                        }
                    }
                    else {
                        let displayName = FileManager.default.displayName(atPath: app)
                        if (displayName != "Do Nothing.app") {
                            let row = SWDATreeRow(displayName, content: handler)
                            category.addChild(row)
                        }
                    }
                }
            }
            let other = SWDATreeRow("Other...",content: SWDAContentHandler(self, appName: "Other...", role:role))
            category.addChild(other)
            let none = SWDATreeRow("Do Nothing",content: SWDAContentHandler(self, appName: "cl.fail.lordkamina.ThisAppDoesNothing", role:role))
            
            category.addChild(none)
            category.children.sort(){($0.rowTitle < $1.rowTitle) && ($0.rowTitle != "Other..." && $0.rowTitle != "Do Nothing")}
            roles.append(category)
        }
        return roles
    }()
    @objc var contentDescription: String = ""
    @objc var contentName: String = ""
    var contentType: SWDAContentType
    
    /** Initializer. contentDescription is only really used for the "Internet" Tab. */
    init (type: SWDAContentType, _ contentName: String, _ contentDescription: String? = nil) {
        self.contentType = type
        super.init()
        self.setValue(contentName, forKey: "contentName")
        if let description = contentDescription {
            self.setValue(description, forKey: "contentDescription")
        }
        else {
            self.setValue(self.getDescription(), forKey: "contentDescription")
        }
    }
    
    @objc lazy var displayName: String = {
        return self.value(forKey:ControllersRef.TabData.displayNameKeyPath) as! String
    }()
    @objc lazy var getExtensions: String = {
        guard self.contentType == .UTI else { return "" }
        if let extensions = copyStringArrayAsString(LSWrappers.UTType.copyExtensionsFor(self.contentName), separator:", ") {
            return "Extensions: \(extensions)"
        }
        else { return "Extensions: " }
    }()
    
    func getDescription () -> String {
        switch self.contentType {
        case .URI:
            if let contentDescription = LSWrappers.Schemes.getNameForScheme(self.contentName as String) {
                self.setValue(contentDescription, forKey: "contentDescription")
                return self.contentDescription
            }
            else { return "" }
        case .UTI: if let desc = (UTTypeCopyDescription(self.contentName as CFString)?.takeRetainedValue() as String?) {
            return desc
        }
        else { return "" }
        case .Application: return ""
        }
    }
    @objc lazy var appPath: String = { return "" }()
    @objc var appIcon: NSImage? = nil
}

/** Our other NSObject subclass adopting the SWDAContentProtocol, represents an Application and all of its associated URI Schemes and UTIs. If an application declares no UTIs, it looks for File Extensions and displays the UTI preferred to represent that extension. */
class SWDAApplicationItem: NSObject, SWDAContentProtocol {
    @objc lazy var contentHandlers: [SWDATreeRow] = {
        var allHandlers: [SWDATreeRow] = []
        if let bundle = self.appBundleInfo {
            let handledContent = bundle.handledContent
            if (bundle.handlesURIs == true) {
                let URIs = SWDATreeRow("URI Schemes")
                let roles = ["Viewer"]
                for role in roles {
                    let row = SWDATreeRow(role)
                    for handler in ((handledContent["URIs"]![role]!)!) {
                        let content = handler.content as! SWDAContentItem
                        let rowName = content.contentName
                        let child = SWDATreeRow(rowName, content: handler)
                        row.addChild(child)
                    }
                    if (row.children.count > 0) { URIs.addChildren(of: row) }
                }
                allHandlers.append(URIs)
            }
            if (bundle.handlesUTIs == true) {
                let UTIs = SWDATreeRow("Uniform Type Identifiers")
                let roles = ["Viewer", "Editor", "Shell"]
                for role in roles {
                    let row = SWDATreeRow(role)
                    for handler in ((handledContent["UTIs"]![role]!)!) {
                        let content = handler.content as! SWDAContentItem
                        let rowName = content.contentName
                        let child = SWDATreeRow(rowName, content: handler)
                        row.addChild(child)
                    }
                    if (row.children.count > 0) { UTIs.addChild(row) }
                }
                allHandlers.append(UTIs)
            }
        }
        return allHandlers
    }()
    @objc var contentDescription: String = ""
    @objc var contentName: String = ""
    var contentType: SWDAContentType
    @objc var appBundleInfo: SWDAApplicationInfo?
    
    /** Determine a hashValue from the Bundle ID to prevent duplicate Applications, since in practice Launch Services will not allow us to choose a specific version of an Application but rather choose the best according to its own set of criteria outlined in the Launch Services Programming Guide. */
    override var hash: Int { return (self.appBundleInfo?.appBundleID)?.hash ?? -1 }
    
    init? (_ app: String) {
        self.contentType = .Application
        if let appInfo = SWDAApplicationInfo(app) {
            self.appBundleInfo = appInfo
            guard (appInfo.handlesURIs == true || appInfo.handlesUTIs == true) else { return nil }
        }
        else { return nil }
        super.init()
        self.setValue(self.appBundleInfo?.displayName, forKey: "contentName")
        self.setValue(self.getDescription(), forKey: "contentDescription")
    }
    @objc lazy var displayName: String = {
        return self.value(forKey:"contentName") as! String
    }()
    
    @objc lazy var appPath: String = {
        if let path = self.appBundleInfo?.appPath {
            return path
        }
        else { return "" }
    }()
    
    @objc lazy var appIcon: NSImage? = {
        if let icon = self.appBundleInfo?.appIcon {
            return icon
        }
        else { return nil }
    }()
    @objc var getExtensions: String = ""
    func getDescription () -> String {
        if let version = self.appBundleInfo?.appVersion {
            return "Version: \(version)"
        }
        else { return "" }
    }
}
