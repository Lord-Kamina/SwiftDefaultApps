/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

@_silgen_name("_LSCopySchemesAndHandlerURLs") func LSCopySchemesAndHandlerURLs(_: UnsafeMutablePointer<NSArray?>, _: UnsafeMutablePointer<NSMutableArray?>) -> OSStatus
@_silgen_name("_LSCopyAllApplicationURLs") func LSCopyAllApplicationURLs(_: UnsafeMutablePointer<NSMutableArray?>) -> OSStatus;
@_silgen_name("_UTCopyDeclaredTypeIdentifiers") func UTCopyDeclaredTypeIdentifiers() -> NSArray

class LSWrappers {
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
    
}
