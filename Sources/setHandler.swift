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
    
    private enum LSErrors:OSStatus {
        case appNotFound = -10814
        case notAnApp = -10811
        case invalidFileURL = 262
        case invalidScheme = -30774
        case deletedApp = -10660
        case serverErr = -10822
        case incompatibleSys = -10825
        case defaultErr = -10810
        
        init(value: OSStatus) {
            switch value {
            case -10814: self = .appNotFound
            case -30774: self = .invalidScheme
            case -10811: self = .notAnApp
            case 262: self = .invalidFileURL
            case -10660: self = .deletedApp
            case -10822: self = .serverErr
            case -10825: self = .incompatibleSys
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
            case .defaultErr: return "An unknown error has occurred."
            }
        }
    }
    
    var failOnUnrecognizedOptions = true
    let name = "setHandler"
    let signature = ""
    let shortDescription = "Sets <application> as the default handler for a given <type>/<subtype> combination."
    private var kind: String?
    private var contentType: String? = nil
    private var inApplication: String = "None"
    private var bundleID: String? = nil
    private var statusCode: OSStatus = kLSUnknownErr
    private var roles: Dictionary = ["Editor":LSRolesMask.editor,"Viewer":LSRolesMask.viewer,"Shell":LSRolesMask.shell,"All":LSRolesMask.all]
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
            if let temp = self.roles[value] {
                self.role = temp
            }
            else { self.role = LSRolesMask.all }
        }
    }
    
    func execute(arguments: CommandArguments) throws  {
        statusCode = LSWrappers().getBundleID(self.inApplication, outBundleID: &bundleID)
        guard (statusCode == 0) else { throw CLIError.error(LSErrors.init(value: statusCode).print(argument: (app: inApplication, content: self.contentType!))); exit(statusCode) }
        switch(kind!) {
            
        case "UTI","URL":
            if let contentString = self.contentType {
                statusCode = ((kind == "URL") ? LSWrappers.Schemes().setDefaultHandler(contentString, bundleID!) : LSWrappers.UTType().setDefaultHandler(contentString, bundleID!, self.role))
            }
            break
        case "http","mailto","ftp","rss","news":
            statusCode = LSWrappers.Schemes().setDefaultHandler(kind!, bundleID!)
            break
            
        default:
            statusCode = kLSUnknownErr
            break
        }
        if (statusCode == 0) { print("Default handler has succesfully changed to \(bundleID!).") }
        else { throw CLIError.error(LSErrors.init(value: statusCode).print(argument: (app: inApplication, content: self.contentType!))) }
    }
}
