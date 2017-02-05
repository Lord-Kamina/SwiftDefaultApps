/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit
import SwiftCLI

@_silgen_name("_LSCopySchemesAndHandlerURLs") func LSCopySchemesAndHandlerURLs(_: UnsafeMutablePointer<NSArray?>, _: UnsafeMutablePointer<NSMutableArray?>) -> OSStatus
@_silgen_name("_LSCopyAllApplicationURLs") func LSCopyAllApplicationURLs(_: UnsafeMutablePointer<NSMutableArray?>) -> OSStatus;
@_silgen_name("_UTCopyDeclaredTypeIdentifiers") func UTCopyDeclaredTypeIdentifiers() -> NSArray

class LSWrappers {
    internal enum LSErrors:OSStatus {
        case appNotFound = -10814
        case notAnApp = -10811
        case invalidFileURL = 262
        case invalidScheme = -30774
        case deletedApp = -10660
        case serverErr = -10822
        case incompatibleSys = -10825
        case defaultErr = -10810
        case invalidBundle = -67857
        
        init(value: OSStatus) {
            switch value {
            case -10814: self = .appNotFound
            case -30774: self = .invalidScheme
            case -10811: self = .notAnApp
            case 262: self = .invalidFileURL
            case -10660: self = .deletedApp
            case -10822: self = .serverErr
            case -10825: self = .incompatibleSys
            case -67857: self = .invalidBundle
            default: self = .defaultErr
            }
            
        }
        func print(argument: (app: String, content: String)) -> String {
            switch self {
            case .notAnApp: return "\(argument.app) is not a valid application."
            case .appNotFound: return "No application found for \(argument.app)"
            case .invalidScheme: return "\(argument.content) is not a valid URL Scheme."
            case .invalidFileURL: return "\(argument.app) is not a valid filesystem URL."
            case .deletedApp: return "\(argument.app) cannot be accessed because it is in the Trash."
            case .serverErr: return "There was an error trying to communicate with the Launch Services Server."
            case .incompatibleSys: return "\(argument.app) is not compatible with the currently installed version of macOS."
            case .invalidBundle: return "\(argument.app) is not a valid Package."
            case .defaultErr: return "An unknown error has occurred."
            }
        }
    }
    class UTType {
        func copyDefaultHandler (_ inUTI:String, inRoles: LSRolesMask = [LSRolesMask.viewer,LSRolesMask.editor]) -> String? { // Unless specifically specified, we only care about viewers and editors, in that order, most of the time.
            if let value = LSCopyDefaultRoleHandlerForContentType(inUTI as CFString, inRoles) {
                let handlerID = (value.takeRetainedValue() as String)
                if let handlerURL = NSWorkspace.shared().urlForApplication(withBundleIdentifier: handlerID) {
                    return handlerURL.path
                }
                else { return nil }
            }
            else { return nil }
        }
        
        func copyAllHandlers (_ inUTI:String, inRoles: LSRolesMask = [LSRolesMask.viewer,LSRolesMask.editor]) -> Array<String>? { // Unless specifically specified, we only care about viewers and editors, in that order, most of the time.
            var handlers: Array<String> = []
            if let value = LSCopyAllRoleHandlersForContentType(inUTI as CFString, inRoles) {
                let handlerIDs = (value.takeRetainedValue() as! Array<String>)
                for handlerID in handlerIDs {
                    if let handlerURL = NSWorkspace.shared().urlForApplication(withBundleIdentifier: handlerID) {
                        handlers.append(handlerURL.path)
                    }
                }
            }
            else { return nil }
            return (handlers.isEmpty ? nil : handlers)
        }
        
        func copyAllUTIs () -> [(key: String, value: String)] {
            let UTIs = (UTCopyDeclaredTypeIdentifiers() as! Array<String>).filter() { UTTypeConformsTo($0 as CFString,"public.item" as CFString) || UTTypeConformsTo($0 as CFString,"public.content" as CFString)} // Ignore UTIs belonging to devices and such.
            var handlers:Array<String> = []
            for UTI in UTIs {
                if let handler = UTType().copyDefaultHandler(UTI) {
                    handlers.append(handler)
                }
                else {
                    handlers.append("No application set.")
                }
            }
            
            let tempdict = Dictionary.init (keys: UTIs, values: handlers)
            return tempdict.sorted(by: { $0.0 < $1.0 })
            
        }
        
        func setDefaultHandler (_ inContent: String, _ inBundleID: String, _ inRoles: LSRolesMask = LSRolesMask.all) -> OSStatus {
            var retval: OSStatus = 0
            if ((LSWrappers().isAppInstalled(withBundleID: inBundleID) == true) || (inBundleID == "None")) {
                retval = LSSetDefaultRoleHandlerForContentType(inContent as CFString, inRoles, inBundleID as CFString)
            }
            else { retval = kLSApplicationNotFoundErr }
            return retval
        }
    }
    
    class Schemes {
        
        func getNameForScheme (_ inScheme: String) -> String? {
            var schemeName: String = nil
            if let handlers = Schemes().copyAllHandlers(inScheme) {
                
                for handler in handlers {
                    
                    if let schemeDicts = (Bundle(path:handler)?.infoDictionary?["CFBundleURLTypes"] as? [[String:AnyObject]]) {
                        
                        for schemeDict in (schemeDicts.filter() { (($0["CFBundleURLSchemes"] as? [String])?.contains() {$0.caseInsensitiveCompare(inScheme) == .orderedSame}) == true } ) {
                            if let name = (schemeDict["CFBundleURLName"] as? String) {
                                
                                schemeName = name
                                return schemeName
                                
                            }
                            else { schemeName = nil }
                            
                        }
                    }
                }
                
            }
            return schemeName
        }
        func copySchemesAndHandlers() -> [(key: String, value: String)]? {
            var schemes_array: NSArray?
            var apps_array: NSMutableArray?
            if (LSCopySchemesAndHandlerURLs(&schemes_array, &apps_array) == 0) {
                if let URLArray = (apps_array! as NSArray) as? [URL] {
                    if let pathsArray = convertAppURLsToPaths(URLArray) {
                        
                        let schemesHandlers = Dictionary.init (keys: schemes_array as! [String], values: pathsArray)
                        let sortedDict = schemesHandlers.sorted(by: { $0.0 < $1.0 })
                        return sortedDict
                    }
                    else { return nil }
                    
                }
                    
                else { return nil }
            }
            else { return nil }
        }
        
        func copyDefaultHandler (_ inScheme:String) -> String? {
            
            if let value = LSCopyDefaultHandlerForURLScheme(inScheme as CFString) {
                let handlerID = (value.takeRetainedValue() as String)
                if let handlerURL = NSWorkspace.shared().urlForApplication(withBundleIdentifier: handlerID) {
                    return handlerURL.path
                }
                else { return nil }
            }
            else { return nil }
        }
        
        func copyAllHandlers (_ inScheme:String) -> Array<String>? {
            
            var handlers: Array<String> = []
            
            if let value = LSCopyAllHandlersForURLScheme(inScheme as CFString) {
                let handlerIDs = (value.takeRetainedValue() as! Array<String>)
                for handlerID in handlerIDs {
                    if let handlerURL = NSWorkspace.shared().urlForApplication(withBundleIdentifier: handlerID) {
                        handlers.append(handlerURL.path)
                    }
                }
            }
            else { return nil }
            return (handlers.isEmpty ? nil : handlers)
        }
        
        func setDefaultHandler (_ inScheme: String, _ inBundleID: String) -> OSStatus {
            var retval: OSStatus = kLSUnknownErr
            if let matches = inScheme =~ /"\\A[a-zA-Z][a-zA-Z0-9.+-]+$" {
                if (matches == true) {
                    if ((LSWrappers().isAppInstalled(withBundleID:inBundleID)) == true || (inBundleID == "None")) {
                        retval = LSSetDefaultHandlerForURLScheme((inScheme as CFString), (inBundleID as CFString))
                    }
                    else { retval = kLSApplicationNotFoundErr }
                }
                else { retval = Int32(kURLUnsupportedSchemeError) }
            }
            else { retval = Int32(kURLUnsupportedSchemeError) }
            return retval
        }
    }
    
    func copyAllApps () -> Array<String>? {
        var apps: NSMutableArray?
        if (LSCopyAllApplicationURLs(&apps) == 0) {
            if let appURLs = (apps! as NSArray) as? [URL] {
                if let pathsArray = convertAppURLsToPaths(appURLs) {
                    
                    return pathsArray
                    
                }
                else { return nil }
            }
            else { return nil }
        }
        else { return nil }
    }
    
    func isAppInstalled (withBundleID: String) -> Bool {
        let temp = withBundleID as CFString
        
        if let appURL = (LSCopyApplicationURLsForBundleIdentifier(temp,nil)?.takeRetainedValue() as NSArray?) {
            return true
        }
        else {
            return false
        }
    }
    
    func getBundleID (_ inParam: String, outBundleID: inout String?) -> OSStatus {
        outBundleID = nil
        var errCode = OSStatus()
        let inURL: URL
        let filemanager = FileManager.default
        if (inParam == "None") { // None is a valid value to remove a handler, so we'll allow it.
            outBundleID = inParam
            return 0
        }
        if let appPath = NSWorkspace.shared().absolutePathForApplication(withBundleIdentifier: inParam)  { // Check whether we have a valid Bundle ID for an application.
            outBundleID = inParam
            return 0
        }
        else if let appPath = NSWorkspace.shared().fullPath(forApplication: inParam) { // Or an application designed by name
            if let bundle = Bundle(path:appPath) {
                if let type = bundle.getType(outError: &errCode) {
                    if (type == "APPL") {
                        outBundleID = bundle.bundleIdentifier!
                        return 0
                    }
                    else { return kLSNotAnApplicationErr }
                }
                else { return errCode }
            }
            if (filemanager.fileExists(atPath: inParam) == true) { return kLSNotAnApplicationErr }
            else { return kLSApplicationNotFoundErr }
        }
            
        else {
            if let bundle = Bundle(path: inParam) { // Is it a valid bundle path?
                if let type = bundle.getType(outError: &errCode) {
                    if (type == "APPL") {
                        outBundleID = bundle.bundleIdentifier!
                        return 0
                    }
                    else { return kLSNotAnApplicationErr }
                }
                else { return errCode }
            }
            else {
                if (filemanager.fileExists(atPath: inParam) == true) { // Maybe it's a valid file path, but not an app bundle?
                    return kLSNotAnApplicationErr
                }
                if let url = URL(string: inParam) { // Let's fallback to an URL.
                    if (url.path != "") {
                        if (url.isFileURL == true) {
                            if (filemanager.fileExists(atPath: url.path) == true) { //Is it a valid app URL?
                                if let bundle = Bundle(url: url) {
                                    if let type = bundle.getType(outError: &errCode) {
                                        if (type == "APPL") {
                                            outBundleID = bundle.bundleIdentifier!
                                            return 0
                                        }
                                        else { return kLSNotAnApplicationErr }
                                    }
                                    else { return errCode }
                                }
                                else { return kLSNotAnApplicationErr } // Maybe it's a valid file URL, but not an app bundle?
                            }
                            else {
                                return kLSApplicationNotFoundErr
                            } // No application found at this location.
                        }
                        else { return kLSNotAnApplicationErr }
                    }
                    else {
                        if (url.isFileURL == false) { return Int32(NSFileReadUnsupportedSchemeError) }
                    }
                }
                else {
                    return kLSNotAnApplicationErr
                }
            }
        }
        return kLSUnknownErr
    }
}
