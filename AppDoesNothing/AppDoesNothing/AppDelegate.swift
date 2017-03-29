//
//  AppDelegate.swift
//  AppDoesNothing
//
//  Created by Gregorio Litenstein Goldzweig on 3/24/17.
//  Copyright © 2017 Gregorio Litenstein Goldzweig. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func handleGetURLEvent(_ event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!) {
        let urlPassed = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue!
        NSLog("Dummy application launched in response to URL: \(urlPassed), will now exit.")
    }
    
    func handleOpenEvent(_ event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!) {
        let documentPassed = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue!
        guard let documentType =  try? NSWorkspace.shared().type(ofFile: URL(string:documentPassed)!.path) else {
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
        NSApplication.shared().terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

