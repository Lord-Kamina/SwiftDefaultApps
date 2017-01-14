//
//  getHandler.swift
//  SwDefaultApps
//
//  Created by Gregorio Litenstein Goldzweig on 12/13/16.
//
//

import Foundation
import SwiftCLI

class ReadCommand: OptionCommand {
    
    let name = "getHandler"
    let signature = ""
    let shortDescription = "Returns the default application registered for the protocol or <subtype> you specify."
    
    private var kind: String?
    private var getAll = false;
    private var contentType: String? = nil
    private var handler: String? = nil
    
    func setupOptions(options: OptionRegistry) {
        options.add(keys: ["--UTI"], usage: "Return the default application for <subtype>", valueSignature: "subtype") { [unowned self] (value) in
            self.contentType = value
            self.kind = "UTI"
        }
        options.add(keys: ["--URL"], usage: "Return the default application for <subtype>", valueSignature: "subtype") { [unowned self] (value) in
            self.contentType = value
            self.kind = "URL"
        }
        options.add(flags: ["--internet", "--browser", "--web"], usage: "Returns the default web browser.") {
            self.contentType = nil
            self.kind = "http"
        }
        options.add(flags: ["--mail", "--email", "--e-mail"], usage: "Returns the default e-mail client.") {
            self.contentType = nil
            self.kind = "mailto"
        }
        options.add(flags: ["--ftp"], usage: "Returns the default FTP client.") {
            self.contentType = nil
            self.kind = "ftp"
        }
        options.add(flags: ["--rss"], usage: "Returns the default RSS client.") {
            self.contentType = nil
            self.kind = "RSS"
        }
        options.add(flags: ["--news"], usage: "Returns the default news client.") {
            self.contentType = nil
            self.kind = "news"
        }
        options.add(flags: ["--all"], usage: "When this flag is added, a list of all applications registered for that content will printed.") {
            self.getAll = true
        }
    }
    
    func execute(arguments: CommandArguments) throws  {
        
        switch(kind!,getAll) {
            
        case ("UTI",true),("URL",true):
            
            if let contentString = self.contentType {
                
                handler = copyStringArrayAsString( ((kind == "URL") ? LSWrappers.Schemes().copyAllHandlers(contentString) : LSWrappers.UTType().copyAllHandlers(contentString)) )
                
            }
            break
            
        case ("UTI",false),("URL",false):
            
            if let contentString = self.contentType {
                
                handler = ((kind == "URL") ? LSWrappers.Schemes().copyDefaultHandler(contentString) : LSWrappers.UTType().copyDefaultHandler(contentString))
            }
            break
        case ("http",Bool()),("mailto",Bool()),("ftp",Bool()),("rss",Bool()),("news",Bool()):
            
            handler = LSWrappers.Schemes().copyDefaultHandler(kind!)
            
            break
            
        default:
            
            handler = nil
            
            break
        }
        
        if (nil != handler) { print(handler!) } else { throw CLIError.error(("An incompatible combination was used, or no application is registered to handle \(self.contentType!)")) }
    }
}
