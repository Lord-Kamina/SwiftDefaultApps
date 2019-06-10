/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit


/** Represents information about an application and its associated URI Schemes and UTIs as an object. */
class SWDAApplicationInfo: NSObject {
    var displayName: String?
    var appPath: String?
    var appURL: String?
    var appDescription: String?
    var appVersion: String?
    var appBundleID: String?
    var appIcon: NSImage?
    lazy var handlers: [SWDAContentHandler] = { return [] }()
    
    lazy var handledContent: [String: [String:[SWDAContentHandler]?]] = {
        var wrappedHandlers: [String: [String:[SWDAContentHandler]?]] = [:]
        if let handlers = LSWrappers.copySchemesAndUTIsForApp(self.appPath!) {
            
            var wrappedURIHandlers: [String:[SWDAContentHandler]] = ["Viewer":[]]
            var wrappedUTIHandlers: [String:[SWDAContentHandler]] = ["Viewer":[],"Editor":[],"Shell":[]]
            
            for handlerRole in handlers["UTIs"]! {
                let role = String(describing:handlerRole.key)
                var handler: SWDAContentHandler?
                
                for utiHandler in handlerRole.value {
                    
                    handler = SWDAContentHandler(SWDAContentItem(type:SWDAContentType(rawValue:"UTI")!, utiHandler), appName: self.appBundleID!, role: SourceListRoleTypes(rawValue:role)!)
                    if let handler = handler {
                        wrappedUTIHandlers[role]!.append(handler)
                    }
                }
            }
            
            for handlerRole in handlers["URIs"]! {
                let role = String(describing:handlerRole.key)
                var handler: SWDAContentHandler?
                
                for urlHandler in handlerRole.value {
                    
                    handler = SWDAContentHandler(SWDAContentItem(type:SWDAContentType(rawValue:"URI")!, urlHandler), appName: self.appBundleID!, role: SourceListRoleTypes(rawValue:role)!)
                    if let handler = handler {
                        wrappedURIHandlers[role]!.append(handler)
                    }
                }
            }
            wrappedHandlers["UTIs"] = wrappedUTIHandlers
            wrappedHandlers["URIs"] = wrappedURIHandlers
            return wrappedHandlers
        }
        else { return ["URIs":["Viewer":[]],"UTIs":["Editor":[], "Viewer":[], "Shell":[]]] }
    }()
    
    /**  Only applications that handle at least one URI Scheme or UTI will show up in the "Applications" tab. */
    lazy var handlesURIs: Bool = {
        for role in (self.handledContent["URIs"]!).values {
            if !(role!.isEmpty) { return true }
        }
        return false
    }()
    lazy var handlesUTIs: Bool = {
        for role in (self.handledContent["UTIs"]!).values {
            if !(role!.isEmpty) { return true }
        }
        return false
    }()
    
    init?(_ inParam: String) {
        var bundleID: String?
        switch inParam {
        case "Other...":
            self.displayName = "Other..."
            self.appVersion = ""
            self.appPath = ""
            self.appIcon = NSImage(byReferencingFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns")
        default:
            let result = LSWrappers.getBundleID(inParam, outBundleID: &bundleID)
            if (result == 0) {
                let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID!)
                guard appURL != nil else { return nil }
                if let bundle = Bundle(url: appURL!) {
					guard bundle.bundleIdentifier != nil else {
						NSLog(LSWrappers.LSErrors.invalidBundle.print(argument: (app: inParam, content:"")))
						return nil;
					}
					self.appBundleID = bundle.bundleIdentifier!
                    let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    var tempName: String?
                    if let displayName = displayName {
                        tempName = displayName
                    }
                    sanity: if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String { // Theoretically, apps should always have a CFBundleName and most of the time, also a CFBundleDisplayName. In practice? Not so much. We should be prepared to handle broken apps.
                        guard (tempName == nil || tempName == "") else { break sanity }
                        tempName = name
                    }
                    else {
                        tempName = FileManager.default.displayName(atPath: bundle.bundlePath)
                    }
                    self.displayName = tempName
                    self.appURL = String(describing:bundle.bundleURL)
                    if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        self.appVersion = version
                    }
                    else if let version = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        self.appVersion = version
                    }
                    else { self.appVersion = nil }
                    self.appPath = bundle.bundlePath
                    self.appIcon = NSWorkspace.shared.icon(forFile: bundle.bundlePath)
                }
                else {
                    NSLog(LSWrappers.LSErrors.init(value:result).print(argument: (app: inParam, content:"")))
                    return nil
                }
            }
            else {
                NSLog(LSWrappers.LSErrors.init(value:result).print(argument: (app: inParam, content:"")))
                return nil
            }
        }
        super.init()
    }
}
