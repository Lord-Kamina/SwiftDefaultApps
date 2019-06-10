/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */
import Foundation
import SwiftCLI

class ReadCommand: OptionCommand {
    
    let name = "getHandler"
    let signature = ""
    let shortDescription = "Returns the default application registered for the URI Scheme or <subtype> you specify."
    
    private var kind: String = ""
    private var getAll = false;
    private var contentType: String? = nil
    private var handler: String? = nil
    private var roles: Dictionary = ["editor":LSRolesMask.editor,"viewer":LSRolesMask.viewer,"shell":LSRolesMask.shell,"all":LSRolesMask.all]
    private var role: LSRolesMask = LSRolesMask.all
    
    func setupOptions(options: OptionRegistry) {
        options.addGroup(name:"type", required:true, conflicting:true)
        
        options.add(keys: ["--UTI"], usage: "Return the default application for <subtype>", valueSignature: "subtype", group:"type") { [unowned self] (value) in
            self.contentType = value
            self.kind = "UTI"
        }
        options.add(keys: ["--URL"], usage: "Return the default application for <subtype>", valueSignature: "subtype", group:"type") { [unowned self] (value) in
            self.contentType = value
            self.kind = "URL"
        }
        options.add(flags: ["--internet", "--browser", "--web"], usage: "Returns the default web browser.", group:"type") {
            self.contentType = nil
            self.kind = "http"
        }
        options.add(flags: ["--mail", "--email", "--e-mail"], usage: "Returns the default e-mail client.", group:"type") {
            self.contentType = nil
            self.kind = "mailto"
        }
        options.add(flags: ["--ftp"], usage: "Returns the default FTP client.", group:"type") {
            self.contentType = nil
            self.kind = "ftp"
        }
        options.add(flags: ["--rss"], usage: "Returns the default RSS client.", group:"type") {
            self.contentType = nil
            self.kind = "RSS"
        }
        options.add(flags: ["--news"], usage: "Returns the default news client.", group:"type") {
            self.contentType = nil
            self.kind = "news"
        }
        options.add(flags: ["--all"], usage: "When this flag is added, a list of all applications registered for that content will printed.") {
            self.getAll = true
        }
        options.add(keys: ["--role"], usage: "--role <Viewer|Editor|Shell|All>, specifies the role with which to register the handler. Default is All.", valueSignature: "role") { [unowned self] (value) in
            if let temp = self.roles[value.lowercased()] {
                self.role = temp
            }
            else { self.role = [LSRolesMask.viewer,LSRolesMask.editor] }
        }
    }
    
    func execute(arguments: CommandArguments) throws  {
        
        switch(kind,getAll) {
            
        case ("UTI",true),("URL",true):
            
            if let contentString = self.contentType {
                
                handler = copyStringArrayAsString( ((kind == "URL") ? LSWrappers.Schemes.copyAllHandlers(contentString) : LSWrappers.UTType.copyAllHandlers(contentString, inRoles: role)) )
                
            }
            break
            
        case ("UTI",false),("URL",false):
            
            if let contentString = self.contentType {
                
                handler = ((kind == "URL") ? LSWrappers.Schemes.copyDefaultHandler(contentString) : LSWrappers.UTType.copyDefaultHandler(contentString, inRoles: role))
            }
            break
        case ("http",Bool()),("mailto",Bool()),("ftp",Bool()),("rss",Bool()),("news",Bool()):
            
            handler = LSWrappers.Schemes.copyDefaultHandler(kind)
            
            break
            
        default:
            
            handler = nil
            
            break
        }
        let arg: String
        if (self.contentType != nil) { arg = self.contentType! }
        else { arg = "<subtype>" }
        
        if (nil != handler) {
            print(handler!)
		} else { throw CLIError.error(("SwiftDefaultApps ERROR: An incompatible combination was used, or no application is registered to handle \(arg)")) }
    }
}
