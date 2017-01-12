//
//  commonFuncs.swift
//  SwDefaultApps
//
//  Created by Gregorio Litenstein Goldzweig on 1/12/17.
//
//

import Foundation

func copyDictionaryAsString (_ inDict: [(key:String, value:String)]?) -> String? {
    
    var output = ""
    
    if let temp = inDict {
    
        for (key, value) in temp {
            output+=(key+" "+value+"\n")
        }
    }
    else { return nil }
    return output
}

func copyStringArrayAsString (_ inArray: Array<String>?) -> String? {
    if let temp = inArray {
    return temp.joined(separator:"\n")
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
