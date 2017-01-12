//
//  getSchemes.swift
//  SwDefaultApps
//
//  Created by Gregorio Litenstein Goldzweig on 1/10/17.
//
//

import Foundation
import SwiftCLI

class GetSchemes: Command {
    
    let name = "getSchemes"
    let signature = ""
    let shortDescription = "Returns a list of all known URL schemes, accompanied by their default handler."
    
    func execute(arguments: CommandArguments) throws  {
        
        if let output = copyDictionaryAsString(LSWrappers.Schemes().copySchemesAndHandlers()) {
            
            print(output)
        }
        else { throw CLIError.error("There was an error generating the list.") }
        
    }
}
