//
//  getApps.swift
//  SwDefaultApps
//
//  Created by Gregorio Litenstein Goldzweig on 1/10/17.
//
//

import Foundation
import SwiftCLI


class GetApps: Command {
    
    let name = "getApps"
    let signature = ""
    let shortDescription = "Returns a list of all registered applications."
    
    func execute(arguments: CommandArguments) throws  {
        
        if let output = copyStringArrayAsString(LSWrappers().copyAllApps()) {
            print(output)
        }
        else { throw CLIError.error("There was an error generating the list of applications.") }
    }
}
