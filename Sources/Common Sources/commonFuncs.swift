/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import Foundation

/**
 Creates a String representation of a Dictionary of Strings.
 - Parameter inDict: A dictionary of Strings.
 - Returns: A string corresponding to the contents of the supplied dictionary.
 */
func copyDictionaryAsString (_ inDict: [(key:String, value:String)]?) -> String? {
    var output = ""
    if let temp = inDict {
        
        for (key, value) in temp {
            output+=("\(key)\t\t\t\t\(value)\n")
        }
    }
    else { return nil }
    return output
}

/**
 Creates a String representation of an Array of Strings.
 - Parameter inArray: An array of strings.
 - Parameter separator: The separator to be used.
 - Returns: A string corresponding to the contents of the supplied array.
 */
func copyStringArrayAsString (_ inArray: Array<String>?, separator: String = "\n") -> String? {
    if let temp = inArray {
        return temp.joined(separator:separator)
    }
    else { return nil }
}

extension Dictionary
{
    public init(keys: [Key], values: [Value])
    {
        precondition(keys.count == values.count)
        
        self.init()
        
        for (index, key) in keys.enumerated()
        {
            self[key] = values[index]
        }
    }
}
/**
 Converts an array of Application URLs to an array of Application Paths.
 - Parameter inArray: An array of file-system URLs corresponding to applications.
 - Returns: An array of strings corresponding to the POSIX paths of the supplied applications.
 */
func convertAppURLsToPaths (_ inArray:Array<URL>?) -> Array<String>? {
    if let URLArray = inArray {
        var outputArray: Array<String> = []
        for (i, app) in URLArray.enumerated() {
            let temp = app.path
            outputArray.insert(temp, at:i)
        }
        return outputArray
    }
    else { return nil }
}

infix operator =~
prefix operator /

func =~ (string: String, regex: NSRegularExpression?) -> Bool? {
    guard let matches = regex?.numberOfMatches(in:string,
                                               options: [],
                                               range: NSMakeRange(0, string.characters.count))
        else { return nil }
    return matches > 0
}

prefix func /(pattern:String) -> NSRegularExpression? {
    let options: NSRegularExpression.Options =
        NSRegularExpression.Options.dotMatchesLineSeparators
    guard let retval = try? NSRegularExpression(pattern:pattern,
                                                options:options) else { return nil }
    return retval
}

extension Bundle {
    /**
     Copies a bundle's package type, as specified in its Info.plist.
     - Parameter outError: Populated with an error-code if the bundle does not correspond to an application.
     - Returns: The four-letter code specifying the bundle's package type, or `nil` if an error is encountered.
     */
    func getType (outError: inout OSStatus) -> String? {
        if let info = self.infoDictionary {
            if let type = info["CFBundlePackageType"] {
                return String(describing: type)
            }
            else { outError = errSecInvalidBundleInfo; return nil }
        }
        else { outError = kLSUnknownErr; return nil }
    }
}
