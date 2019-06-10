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


class GetApps: Command {
    
    let name = "getApps"
    let signature = ""
    let shortDescription = "Returns a list of all registered applications."
    
    func execute(arguments: CommandArguments) throws  {
        
        if let output = copyStringArrayAsString(LSWrappers.copyAllApps()) {
            print(output)
        }
        else { throw CLIError.error("SwiftDefaultApps ERROR: Couldn't generate the list of installed applications.") }
    }
}
