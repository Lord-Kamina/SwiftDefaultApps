/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import Foundation

/** Represent LSRolesMask in a more convenient format for us. */
enum SourceListRoleTypes:String {
    case Editor, Viewer, Shell, All
}

/** Represent possible kinds of NSObject conforming to SWDAContentProtocol */
internal enum SWDAContentType: String {
    case UTI, URI, Application
}


/** Our main model class, tasked with getting and populating the content arrays associated with each tab. */
class SWDAHandlersModel: NSObject {
    @objc static var allUTIs: [SWDAContentItem]?
    @objc static var allSchemes: [SWDAContentItem]?
    @objc static var internetSchemes: [SWDAContentItem]?
    @objc static var allApps: [SWDAApplicationItem]?
    
    /**
     This function is indirectly called by the contentArray variable in each SWDATabTemplate instance, it's responsible for asynchronously populating each model array with the appropriate content and sending messages for the ProgressAlert to update itself.
     - Parameter view: The SWDATabView instance that requested the content. We pass this so we can then modify its backing-store in a KVO-compliant manner via setValue(_:forKey:)
     - Parameter type: String representation of what that SWDATabTemplate is asking for.
     - Parameter competionHandler: Code block to execute upon completion. In practice, what this does is invoke setValue(_:forKey:) with the resulting array as the value.
     */
    static internal func populateContentArray(in view: SWDATabTemplate, with type: String, completionHandler: @escaping () -> Void) {
        let progressAlert = ProgressAlert()
        
        guard (ControllersRef.sharedInstance.thePrefPane?.mainCustomView.window != nil) else { return }
        let window = (ControllersRef.sharedInstance.thePrefPane?.mainCustomView.window)!
        
        progressAlert.beginSheetModal(for: window, completionHandler: nil)
        
        var codeBlock: (_ : Int) -> Void = { index in }
        var sourceItems: [String] = []
        var sourceDescriptions: [String:String] = [:]
        var outputItems: Any // By using the SynchronizedArray class, we can concurrently create the larger Content Arrays across multiple threads, in a safe manner.
        if (type == "Applications") {
            outputItems = SynchronizedArray<SWDAApplicationItem>()
        }
        else {
            outputItems = SynchronizedArray<SWDAContentItem>()
        }
        switch type {
        case "Internet":
            sourceItems = ["http","mailto","news","rss","ftp","im"]
            sourceDescriptions = ["http":"Web Browser","mailto":"E-Mail","news":"News","rss":"RSS","ftp":"FTP","im":"Instant Messaging"] // In practice, these are just shortcuts for the most commonly-used URI Schemes.
            codeBlock = {
                index in
                let i = Int(index)
                (outputItems as! SynchronizedArray<SWDAContentItem>).append(SWDAContentItem(type:SWDAContentType(rawValue: "URI")!, sourceItems[i], sourceDescriptions[sourceItems[i]]))
                DispatchQueue.main.async { [weak progressAlert] in
                    progressAlert?.increment(by: 1)
                }
            }
        case "URIs":
            if let schemesHandlers = LSWrappers.Schemes.copySchemesAndHandlers() {
                sourceItems = Array(schemesHandlers.keys)
            }
            else { return }
            codeBlock = {
                index in
                let i = Int(index)
                if sourceItems[i] != "*" {
                    (outputItems as! SynchronizedArray<SWDAContentItem>).append(SWDAContentItem(type:SWDAContentType(rawValue: "URI")!, sourceItems[i]))
                }
                DispatchQueue.main.async { [weak progressAlert] in
                    progressAlert?.increment(by: 1)
                }
            }
        case "UTIs":
            sourceItems = Array(LSWrappers.UTType.copyAllUTIs().keys)
            codeBlock = {
                index in
                let i = Int(index)
                (outputItems as! SynchronizedArray<SWDAContentItem>).append(SWDAContentItem(type:SWDAContentType(rawValue: "UTI")!, sourceItems[i]))
                DispatchQueue.main.async { [weak progressAlert] in
                    progressAlert?.increment(by: 1)
                }
            }
        case "Applications":
            if let apps = LSWrappers.copyAllApps() {
                sourceItems = apps
            }
            else { return }
            codeBlock = {
                index in
                let i = Int(index)
                let app = sourceItems[i]
                if let wrappedApp = SWDAApplicationItem(app) {
                    if ((outputItems as! SynchronizedArray<SWDAApplicationItem>).first() { $0.appBundleInfo?.appBundleID == wrappedApp.appBundleInfo?.appBundleID } == nil) { (outputItems as! SynchronizedArray<SWDAApplicationItem>).append(wrappedApp) }
                }
                DispatchQueue.main.async { [weak progressAlert] in
                    progressAlert?.increment(by: 1)
                }
            }
        default: return
        }
        progressAlert.maxValue = Double(sourceItems.count)
        
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.concurrentPerform(iterations: sourceItems.count, execute: codeBlock)
            
            DispatchQueue.main.sync { [weak window] in // Using sync for the finalization of the array ensures all the data is in place before reporting completion to the View Controller.
                var finalArray: Array<AnyObject>
                if (type == "Applications") {
                    finalArray = (outputItems as! SynchronizedArray<SWDAApplicationItem>).innerArray
                }
                else {
                    finalArray = (outputItems as! SynchronizedArray<SWDAContentItem>).innerArray
                }
                setValue(finalArray, forKey: ControllersRef.TabData.modelArrayKeyPath)
                window?.endSheet(progressAlert.window)
                completionHandler()
            }
        }
    }
}
