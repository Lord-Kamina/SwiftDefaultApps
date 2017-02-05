/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import Foundation

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
