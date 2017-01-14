//
//  getUTIs.swift
//  SwDefaultApps
//
//  Created by Gregorio Litenstein Goldzweig on 1/10/17.
//
//

import Foundation
import SwiftCLI

class GetUTIs: Command {
    
    let name = "getUTIs"
    let signature = ""
    let shortDescription = "Returns a list of all known UTIs, and their default handler."
    
    func execute(arguments: CommandArguments) throws  {
        
        let UTIs = LSWrappers.UTType().copyAllUTIs()
        
        print(copyDictionaryAsString(UTIs)!)
        
    }
    
}
