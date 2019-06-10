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

class SetCommand: OptionCommand {
    var failOnUnrecognizedOptions = true
    let name = "setHandler"
    let signature = ""
    let shortDescription = "Sets <application> as the default handler for a given <type>/<subtype> combination."
    private var kind: String = ""
    private var contentType: String? = nil
    private var inApplication: String = "None"
    private var bundleID: String? = nil
    private var statusCode: OSStatus = kLSUnknownErr
    private var roles: Dictionary = ["editor":LSRolesMask.editor,"viewer":LSRolesMask.viewer,"shell":LSRolesMask.shell,"all":LSRolesMask.all]
    private var role: LSRolesMask = LSRolesMask.all
    
    func setupOptions(options: OptionRegistry) {
        options.addGroup(name:"type", required:true, conflicting:true)
        options.addGroup(name:"application", required:true, conflicting:true)
        options.add(keys: ["--UTI"], usage: "Change the default application for <subtype>", valueSignature: "subtype", group:"type") { [unowned self] (value) in
            self.contentType = value
            self.kind = "UTI"
        }
        options.add(keys: ["--URL"], usage: "Change the default application for <subtype>", valueSignature: "subtype", group:"type") { [unowned self] (value) in
            self.contentType = value
            self.kind = "URL"
        }
        
        options.add(flags: ["--internet", "--browser", "--web"], usage: "Changes the default web browser.", group:"type") {
            self.contentType = nil
            self.kind = "http"
        }
        options.add(flags: ["--mail", "--email", "--e-mail"], usage: "Changes the default e-mail client.", group:"type") {
            self.contentType = nil
            self.kind = "mailto"
        }
        options.add(flags: ["--ftp"], usage: "Changes the default FTP client.", group:"type") {
            self.contentType = nil
            self.kind = "ftp"
        }
        options.add(flags: ["--rss"], usage: "Changes the default RSS client.", group:"type") {
            self.contentType = nil
            self.kind = "RSS"
        }
        options.add(flags: ["--news"], usage: "Changes the default news client.", group:"type") {
            self.contentType = nil
            self.kind = "news"
        }
        options.add(keys: ["--app", "--application"], usage: "The <application> to register as default handler. Specifying \"None\" will remove the currently registered handler.", valueSignature: "application", group:"application") { [unowned self] (value) in
            self.inApplication = value
        }
        options.add(keys: ["--role"], usage: "--role <Viewer|Editor|Shell|All>, specifies the role with which to register the handler. Default is All.", valueSignature: "role") { [unowned self] (value) in
            if let temp = self.roles[value.lowercased()] {
                self.role = temp
            }
            else { self.role = LSRolesMask.all }
        }
    }
    
    func execute(arguments: CommandArguments) throws  {
        statusCode = LSWrappers.getBundleID(self.inApplication, outBundleID: &bundleID)
        guard (statusCode == 0) else { throw CLIError.error(LSWrappers.LSErrors.init(value: statusCode).print(argument: (app: inApplication, content: self.contentType!))) }
        switch(kind) {
        case "UTI","URL":
            if let contentString = self.contentType {
                statusCode = ((kind == "URL") ? LSWrappers.Schemes.setDefaultHandler(contentString, bundleID!) : LSWrappers.UTType.setDefaultHandler(contentString, bundleID!, self.role))
            }
            break
        case "http","mailto","ftp","rss","news":
            statusCode = LSWrappers.Schemes.setDefaultHandler(kind, bundleID!)
            break
            
        default:
            statusCode = kLSUnknownErr
            break
        }
		do {
		try displayAlert(error: statusCode, arg1: (bundleID != nil ? bundleID : inApplication), arg2: self.contentType!)
		} catch { print(error) }
    }
}
