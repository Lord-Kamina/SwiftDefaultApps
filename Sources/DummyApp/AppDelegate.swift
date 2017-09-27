/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!) {
        let urlPassed = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue!
        NSLog("Dummy application launched in response to URL: \(urlPassed), will now exit.")
    }
    
    @objc func handleOpenEvent(_ event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!) {
        let documentPassed = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue!
        guard let documentType =  try? NSWorkspace.shared.type(ofFile: URL(string:documentPassed)!.path) else {
            NSLog("Dummy application launched in response to file with unknown type, will now exit.")
            return
        }
        NSLog("Dummy application launched in response to file of type: \(documentType), will now exit.")
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.handleGetURLEvent(_:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.handleOpenEvent(_:withReplyEvent:)), forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(kAEOpenDocuments))
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

