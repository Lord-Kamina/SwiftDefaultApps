/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import PreferencePanes

/** Main PreferencePane class */

class SWDAMainPrefPane: NSPreferencePane {
    @IBOutlet weak var mainCustomView: NSView!
    @IBOutlet weak var tabViewController: SWDATabViewController?

/** Populate our utility singleton with instances of the views and TabView Controller; initialize tabs. */
    override func assignMainView() {
        ControllersRef.sharedInstance.tabViewController = self.tabViewController
        ControllersRef.sharedInstance.thePrefPane = self
        ControllersRef.sharedInstance.theMainView = self.mainCustomView
        super.assignMainView()
    }
/** Add the TabView Controller to the Main View and load content for the default tab. */
    override func mainViewDidLoad() {
        	super.mainViewDidLoad()
			self.tabViewController!.view.translatesAutoresizingMaskIntoConstraints = false
			ControllersRef.sharedInstance.theMainView.addSubview(self.tabViewController!.tabView)
		}
/** Initialize the content array when the pane is first opened. */
	override func didSelect() {
		ControllersRef.TabData.getContentArray(for: (ControllersRef.sharedInstance.tabViewController?.tabViewItems[0].view as! SWDATabTemplate), initialSetup: true)
	}
    
@IBAction func showAboutDialog(_ sender: NSButton) {
    let mainBundle = Bundle(identifier: "cl.fail.lordkamina.SwiftDefaultApps")
    let appVersionString: String = mainBundle?.object(forInfoDictionaryKey:"CFBundleShortVersionString") as! String
    let buildNumberString: String = mainBundle?.object(forInfoDictionaryKey:"CFBundleVersion") as! String
    
        let alert = NSAlert()
        alert.window.title = "About"
        alert.messageText = "SwiftDefaultApps, v. \(appVersionString) build \(buildNumberString)"
    alert.informativeText = "by Gregorio Litenstein."
    alert.icon = ControllersRef.appIcon
    alert.accessoryView = HyperlinkTextField(frame: NSRect(x: 0, y:10, width:330, height:18), url: "http://www.github.com/Lord-Kamina/SwiftDefaultApps")

    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.layout()

        DispatchQueue.main.async {
            alert.runModal()
        }
    }
}
