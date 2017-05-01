/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

/** Create a progressbar and display it on a modal sheet while the Content Array is populated asynchronously. */
class ProgressAlert: NSAlert {
    var progressBar = NSProgressIndicator()
    override init() {
        progressBar.isIndeterminate = false
        progressBar.style = .barStyle
        super.init()
        
        self.messageText = ""
        self.informativeText = "Loading..."
        self.icon = ControllersRef.appIcon
        
        self.accessoryView = NSView(frame: NSRect(x:0, y:0, width: 290, height: 16))
        self.accessoryView?.addSubview(progressBar)
        self.layout()
        self.accessoryView?.setFrameOrigin(NSPoint(x:(self.accessoryView?.frame)!.minX,y:self.window.frame.maxY))
        
        self.addButton(withTitle: "")
        progressBar.sizeToFit()
        progressBar.setFrameSize(NSSize(width:290, height: 16))
        progressBar.usesThreadedAnimation = true
    }
    
    func increment(by value:Double) {
        progressBar.increment(by: value)
    }
    var maxValue: Double {
        get {
            return progressBar.maxValue
        }
        set {
            progressBar.maxValue = newValue
        }
    }
}
