/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

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

//// REGEX MATCHING CONVENIENCE OPERATORS.

infix operator =~
prefix operator /

func =~ (string: String, regex: NSRegularExpression?) -> Bool? {
    guard let matches = regex?.numberOfMatches(in:string,
                                               options: [],
                                               range: NSMakeRange(0, string.count))
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


//// EXTENSIONS

extension DispatchQueue {
	static let labelPrefix = "io.zamzam.ZamzamKit"
	static let database = DispatchQueue(label: "\(DispatchQueue.labelPrefix).database", qos: .utility)
}

public extension Collection {
	
	/// Element at the given index if it exists.
	///
	/// - Parameter index: index of element.
	subscript(safe index: Index) -> Element? {
		// http://www.vadimbulavin.com/handling-out-of-bounds-exception/
		return indices.contains(index) ? self[index] : nil
	}
}

public extension Collection where Iterator.Element == (String, Any) {
	
	/// Converts collection of objects to JSON string
	var jsonString: String? {
		guard JSONSerialization.isValidJSONObject(self),
			let stringData = try? JSONSerialization.data(withJSONObject: self, options: []) else {
				return nil
		}
		
		return String(data: stringData, encoding: .utf8)
	}
}

public extension Array where Element: Equatable {
	
	/// Array with all duplicates removed from it.
	///
	///     [1, 3, 3, 5, 7, 9].distinct // [1, 3, 5, 7, 9]
	var distinct: [Element] {
		// https://github.com/SwifterSwift/SwifterSwift
		return reduce(into: [Element]()) {
			guard !$0.contains($1) else { return }
			$0.append($1)
		}
	}
	
	/// Remove all duplicates from array.
	///
	///     var array = [1, 3, 3, 5, 7, 9]
	///     array.removeDuplicates()
	///     array // [1, 3, 5, 7, 9]
	mutating func removeDuplicates() {
		self = distinct
	}
	
	/// Removes the first occurance of the matched element.
	///
	///     var array = ["a", "b", "c", "d", "e", "a"]
	///     array.remove("a")
	///     array // ["b", "c", "d", "e", "a"]
	///
	/// - Parameter element: The element to remove from the array.
	mutating func remove(_ element: Element) {
		guard let index = firstIndex(of: element) else { return }
		remove(at: index)
	}
}

extension Bundle {
    /**
     Copies a bundle's package type, as specified in its Info.plist.
     - Parameter outError: Populated with an error-code if the bundle does not correspond to a valid package.
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

extension Dictionary
{
    /**
     Create a Dictionary by Merging two Arrays.
     - Parameter keys: An Array to be used as dictionary keys.
     - Parameter values: An Array to be used as values.
     */
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

#if Prefpane
    extension LSRolesMask {
        /**
         Bridge our custom type to the actual values used in LaunchServices methods.
         */
        init (from value: SourceListRoleTypes) {
            switch value {
            case .Viewer: self = .viewer
            case .Editor: self = .editor
            case .Shell: self = .shell
            case .All: self = .all
            }
        }
    }
    
    extension NSControl {
        /** Shrinks a text label until it fits in a single line in its container. */
        func fitWidth() {
            var absoluteMaxWidth: CGFloat = 0.0
            if let tempWidth = (self.superview?.frame.width) {
                absoluteMaxWidth = tempWidth
                absoluteMaxWidth -= (self.alignmentRectInsets.left + self.alignmentRectInsets.right)
            }
            
            let text = self.stringValue
            guard self.font != nil else { return }
            var font = self.font!
            
            if ControllersRef.sharedInstance.originalFonts[self] == nil {
                ControllersRef.sharedInstance.originalFonts[self] = font
            }
            else { font = ControllersRef.sharedInstance.originalFonts[self]! }
            
            let richText = NSTextFieldCell(textCell:text)
            richText.font = font
            var neededWidth: CGFloat = richText.cellSize.width
            var fontSize = font.pointSize
            var newFont = font
            guard absoluteMaxWidth > 0.0 else { return }
            while (neededWidth >= absoluteMaxWidth) {
                guard fontSize > 0.0 else { return }
                fontSize -= 0.5
                newFont = NSFont(descriptor:font.fontDescriptor, size: fontSize)!
                richText.font = newFont
                neededWidth = richText.cellSize.width
            }
            self.setValue(newFont, forKey:"font")
        }
    }
#endif

/** NSFont extensions to style the different kinds of row in the NSTreeView. */
extension NSFont {
    /** Returns a SmallCaps version of the font it is invoked on. */
    func smallCaps() -> NSFont? {
        let settings = [[NSFontDescriptor.FeatureKey.typeIdentifier: kLowerCaseType, NSFontDescriptor.FeatureKey.selectorIdentifier: kLowerCaseSmallCapsSelector]]
        let attributes: [NSFontDescriptor.AttributeName: AnyObject] = [NSFontDescriptor.AttributeName.featureSettings: settings as AnyObject, NSFontDescriptor.AttributeName.name: fontName as AnyObject]
        return NSFont(descriptor: NSFontDescriptor(fontAttributes: attributes), size: pointSize)
    }
    /** Returns a **Bold** version of the font it is invoked on. */
    func bold() -> NSFont? {
        let fontManager = NSFontManager.shared
        return fontManager.convert(self, toHaveTrait: .boldFontMask)
    }
    /**
     Returns an _Italic_ version of the font it is invoked on.
     - Note: Not currently used.
     */
    func italic() -> NSFont? {
        let fontManager = NSFontManager.shared
        return fontManager.convert(self, toHaveTrait: .italicFontMask)
    }
}
