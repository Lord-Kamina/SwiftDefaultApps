/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

/** Utilitary Singleton containing references to the proper instances of View controllers, tabs, taba data and so on. */
final internal class ControllersRef: NSObject {
    @IBOutlet weak var thePrefPane: SWDAMainPrefPane?
    @IBOutlet weak var theTabView: NSTabView!
    @IBOutlet weak var theMainView: NSView!
    @IBOutlet weak var tabViewController: SWDATabViewController?
    
    /** Store references to the original font of an NSControl to revert effects of fitWidth() when appropriate. */
    var originalFonts: [NSControl:NSFont] = [:]
    
    /** Store a reference to the main icon, since we cannot use mainBundle on a preference pane. */
    static let appIcon: NSImage = NSWorkspace.shared.icon(forFile: Bundle(identifier: "cl.fail.lordkamina.SwiftDefaultApps")!.bundlePath)
    
    /** Information relevant to the different tabs, such as labels, Keypaths for their content arrays, and such. */
    enum TabData {
        /** Transform Tab names to abstract cases. */
        enum tabNames:String {
            case Internet
            case URIs
            case UTIs
            case Applications
            init? (value: String?) {
                if let value = value {
                    switch value {
                    case "Internet": self = .Internet
                    case "URI Schemes": self = .URIs
                    case "Uniform Type Identifiers": self = .UTIs
                    case "Applications": self = .Applications
                    default: return nil
                    }
                }
                else { return nil }
            }
        }
        
        /** Return a tab's label. */
        static var Tab: String? {
            let name = tabNames(value:(ControllersRef.sharedInstance.tabViewController?.currentTab?.label))
            return name?.rawValue
        }
        
        /** Store a reference to the appropriate Keypath to an item's Display Name (the title of the Detail View). */
        static var displayNameKeyPath: String {
            if let Tab = Tab {
                switch Tab {
                case "Internet": return "contentDescription"
                case "URIs": return "contentName"
                case "UTIs": return "contentName"
                case "Applications": return "displayName"
                default: return "contentName"
                }
            }
            else { return "contentName" }
        }
        
        /** Stores a reference to the appropriate Keypath for each tab's Content Array. */
        static var modelArrayKeyPath: String {
            if let Tab = Tab {
                var modelArray = ""
                
                switch Tab {
                case "Internet": modelArray = #keyPath(SWDAHandlersModel.internetSchemes)
                case "URIs": modelArray = #keyPath(SWDAHandlersModel.allSchemes)
                case "UTIs": modelArray = #keyPath(SWDAHandlersModel.allUTIs)
                case "Applications": modelArray = #keyPath(SWDAHandlersModel.allApps)
                default: modelArray = ""
                }
                return modelArray
            }
            else { return "" }
        }
        /** Return or populate each tab's Content Array. */
        static func getContentArray (for view: SWDATabTemplate, initialSetup: Bool = false) {
            
            if let Tab = Tab {
                let modelArray = (initialSetup == true) ? #keyPath(SWDAHandlersModel.internetSchemes) : modelArrayKeyPath
                if (SWDAHandlersModel.value(forKey:modelArray) != nil) {
                    view.setValue((SWDAHandlersModel.value(forKey:modelArray) as! Array<AnyObject>), forKey: "contentArrayStore")
                }
                else {
                    SWDAHandlersModel.populateContentArray(in: view, with: Tab) { [unowned view] in
                        view.setValue((SWDAHandlersModel.value(forKey:modelArray) as! Array<AnyObject>), forKey: "contentArrayStore")
                    }
                }
            }
            else { return }
        }
        
        /** Determines whether to show the Item Description in the Detail View. */
        static var shouldShowDescription: Bool {
            if let Tab = Tab {
                switch Tab {
                case "Internet": return false
                case "URIs": return true
                case "UTIs": return true
                case "Applications": return true
                default: return true
                }
            }
            else { return true }
        }
        
        /** Determines whether to show the "Add" button for custom URI Schemes. */
        static var shouldShowAddRemove: Bool {
            if let Tab = Tab {
                switch Tab {
                case "URIs": return true
                default: return false
                }
            }
            else { return false }
        }
        
        /** Determines whether to show an Application's path and a Reveal in Finder button. */
        static var shouldShowAppPath: Bool {
            if let Tab = Tab {
                switch Tab {
                case "Applications": return true
                default: return false
                }
            }
            else { return false }
        }
        
        /** Determines whether to show a list of file extensions associated with a given UTI. */
        static var shouldShowFileExts: Bool {
            if let Tab = Tab {
                switch Tab {
                case "UTIs": return true
                default: return false
                }
            }
            else { return false }
        }
    }
    
    /** Initialize the singleton in a thread-safe way. */
    static let sharedInstance: ControllersRef = ControllersRef()
    
    /** Make sure there are no stray instances. */
    private override init() {
        super.init()
    }
}
