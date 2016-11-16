//
//  SwipeParser.swift
//  Swipe
//
//  Created by satoshi on 6/4/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//
// http://stackoverflow.com/questions/23790143/how-do-i-set-uicolor-to-this-exact-shade-green-that-i-want/23790739#23790739
// dropFirst http://stackoverflow.com/questions/28445917/what-is-the-most-succinct-way-to-remove-the-first-character-from-a-string-in-swi/28446142#28446142

#if os(OSX)
import Cocoa
public typealias UIColor = NSColor
public typealias UIFont = NSFont
#else
import UIKit
#endif
import ImageIO

class SwipeParser {
    //let color = NSRegularExpression(pattern: "#[0-9A-F]6", options: NSRegularExpressionOptions.CaseInsensitive, error: nil)
    static let colorMap = [
        "red":UIColor.red,
        "black":UIColor.black,
        "blue":UIColor.blue,
        "white":UIColor.white,
        "green":UIColor.green,
        "yellow":UIColor.yellow,
        "purple":UIColor.purple,
        "gray":UIColor.gray,
        "darkGray":UIColor.darkGray,
        "lightGray":UIColor.lightGray,
        "brown":UIColor.brown,
        "orange":UIColor.orange,
        "cyan":UIColor.cyan,
        "magenta":UIColor.magenta
    ]
    
    static let regexColor = try! NSRegularExpression(pattern: "^#[A-F0-9]*$", options: NSRegularExpression.Options.caseInsensitive)

    static func parseColor(_ value:Any?, defaultColor:CGColor = UIColor.clear.cgColor) -> CGColor {
        if value == nil {
            return defaultColor
        }
        if let rgba = value as? [String: Any] {
            var red:CGFloat = 0.0, blue:CGFloat = 0.0, green:CGFloat = 0.0
            var alpha:CGFloat = 1.0
            if let v = rgba["r"] as? CGFloat {
                red = v
            }
            if let v = rgba["g"] as? CGFloat {
                green = v
            }
            if let v = rgba["b"] as? CGFloat {
                blue = v
            }
            if let v = rgba["a"] as? CGFloat {
                alpha = v
            }
            return UIColor(red: red, green: green, blue: blue, alpha: alpha).cgColor
        } else if let key = value as? String {
            if let color = colorMap[key] {
                return color.cgColor
            } else {
                let results = regexColor.matches(in: key, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, key.characters.count))
                if results.count > 0 {
                    let hex = String(key.characters.dropFirst())
                    let cstr = hex.cString(using: String.Encoding.ascii)
                    let v = strtoll(cstr!, nil, 16)
                    //NSLog("SwipeParser hex=\(hex), \(value)")
                    var r = Int64(0), g = Int64(0), b = Int64(0), a = Int64(255)
                    switch(hex.characters.count) {
                    case 3:
                        r = v / 0x100 * 0x11
                        g = v / 0x10 % 0x10 * 0x11
                        b = v % 0x10 * 0x11
                    case 4:
                        r = v / 0x1000 * 0x11
                        g = v / 0x100 % 0x10 * 0x11
                        b = v / 0x10 % 0x10 * 0x11
                        a = v % 0x10 * 0x11
                    case 6:
                        r = v / 0x10000
                        g = v / 0x100
                        b = v
                    case 8:
                        r = v / 0x1000000
                        g = v / 0x10000
                        b = v / 0x100
                        a = v
                    default:
                        break;
                    }
                    return UIColor(red: CGFloat(r)/255, green: CGFloat(g%256)/255, blue: CGFloat(b%256)/255, alpha: CGFloat(a%256)/255).cgColor
                }
                return UIColor.red.cgColor
            }
        }
        return UIColor.green.cgColor
    }
    
    static func transformedPath(_ path:CGPath, param:[String:Any]?, size:CGSize) -> CGPath? {
        if let value = param {
            var scale:CGSize?
            if let s = value["scale"] as? CGFloat {
                scale = CGSize(width: s, height: s)
            }
            if let scales = value["scale"] as? [CGFloat], scales.count == 2 {
                scale = CGSize(width: scales[0], height: scales[1])
            }
            
            if let s = scale {
                var xf = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
                xf = xf.scaledBy(x: s.width, y: s.height)
                xf = xf.translatedBy(x: -size.width / 2, y: -size.height / 2)
                return path.copy(using: &xf)!
            }
        }
        return nil
    }
    
    static func parseTransform(_ param:[String:Any]?, scaleX:CGFloat, scaleY:CGFloat, base:[String:Any]?, fSkipTranslate:Bool, fSkipScale:Bool) -> CATransform3D? {
        if let p = param {
            var value = p
            var xf = CATransform3DIdentity
            var hasValue = false
            if let b = base {
                for key in ["translate", "rotate", "scale"] {
                    if let v = b[key], value[key]==nil {
                        value[key] = v
                    }
                }
            }
            if fSkipTranslate {
                if let b = base,
                    let translate = b["translate"] as? [CGFloat], translate.count == 2{
                    xf = CATransform3DTranslate(xf, translate[0] * scaleX, translate[1] * scaleY, 0)
                }
            } else {
                if let translate = value["translate"] as? [CGFloat] {
                    if translate.count == 2 {
                        xf = CATransform3DTranslate(xf, translate[0] * scaleX, translate[1] * scaleY, 0)
                    }
                    hasValue = true
                }
            }
            if let depth = value["depth"] as? CGFloat {
                xf = CATransform3DTranslate(xf, 0, 0, depth)
                hasValue = true
            }
            if let rot = value["rotate"] as? CGFloat {
                xf = CATransform3DRotate(xf, rot * CGFloat(M_PI / 180.0), 0, 0, 1)
                hasValue = true
            }
            if let rots = value["rotate"] as? [CGFloat], rots.count == 3 {
                let m = CGFloat(M_PI / 180.0)
                xf = CATransform3DRotate(xf, rots[0] * m, 1, 0, 0)
                xf = CATransform3DRotate(xf, rots[1] * m, 0, 1, 0)
                xf = CATransform3DRotate(xf, rots[2] * m, 0, 0, 1)
                hasValue = true
            }
            if !fSkipScale {
                if let scale = value["scale"] as? CGFloat {
                    xf = CATransform3DScale(xf, scale, scale, 1.0)
                    hasValue = true
                }
                // LATER: Use "where"
                if let scales = value["scale"] as? [CGFloat] {
                    if scales.count == 2 {
                        xf = CATransform3DScale(xf, scales[0], scales[1], 1.0)
                    }
                    hasValue = true
                }
            }
            return hasValue ? xf : nil
        }
        return nil
    }

    static func parseSize(_ param:Any?, defaultValue:CGSize = CGSize(width: 0.0, height: 0.0), scale:CGSize) -> CGSize {
        if let values = param as? [CGFloat], values.count == 2 {
            return CGSize(width: values[0] * scale.width, height: values[1] * scale.height)
        }
        return CGSize(width: defaultValue.width * scale.width, height: defaultValue.height * scale.height)
    }
    
    static func parseFloat(_ param:Any?, defaultValue:Float = 1.0) -> Float {
        if let value = param as? Float {
            return value
        }
        return defaultValue
    }

    static func parseCGFloat(_ param:Any?, defaultValue:CGFloat = 0.0) -> CGFloat {
        if let value = param as? CGFloat {
            return value
        }
        return defaultValue
    }

    static func parseAndEvalBool(_ originator: SwipeNode, key: String, info: [String:Any]) -> Bool? {
        var valObj: Any?
        
        if let keyInfo = info[key] as? [String:Any], let valOfInfo = keyInfo["valueOf"] as? [String:Any] {
            valObj = originator.getValue(originator, info:valOfInfo)
        } else {
            valObj = info[key]
        }
        
        if let val = valObj as? Bool {
            return val
        } else if let val = valObj as? Int {
            return val != 0
        } else {
            return nil
        }
    }

    //
    // This function performs the "deep inheritance"
    //   Object property: Instance properties overrides Base properties
    //   Array property: Merge (inherit properties in case of "id" matches, otherwise, just append)
    //
    static func inheritProperties(_ object:[String:Any], baseObject:[String:Any]?) -> [String:Any] {
        var ret = object
        if let prototype = baseObject {
            for (keyString, value) in prototype {
                if ret[keyString] == nil {
                    // Only the baseObject has the property
                    ret[keyString] = value
                } else if let arrayObject = ret[keyString] as? [[String:Any]], let arrayBase = value as? [[String:Any]] {
                    // Each has the property array. We need to merge them
                    var retArray = arrayBase
                    var idMap = [String:Int]()
                    for (index, item) in retArray.enumerated() {
                        if let key = item["id"] as? String {
                            idMap[key] = index
                        }
                    }
                    for item in arrayObject {
                        if let key = item["id"] as? String {
                            if let index = idMap[key] {
                                // id matches, merge them
                                retArray[index] = SwipeParser.inheritProperties(item, baseObject: retArray[index])
                            } else {
                                // no id match, just append
                                retArray.append(item)
                            }
                        } else {
                            // no id, just append
                            retArray.append(item)
                        }
                    }
                    ret[keyString] = retArray
                } else if let objects = ret[keyString] as? [String:Any], let objectsBase = value as? [String:Any] {
                    // Each has the property objects. We need to merge them.  Example: '"events" { }'
                    var retObjects = objectsBase
                    for (key, val) in objects {
                        retObjects[key] = val
                    }
                    ret[keyString] = retObjects
                }
            }
        }
        return ret
    }
    
    /*
    static func imageWith(name:String) -> UIImage? {
        var components = name.componentsSeparatedByString("/")
        if components.count == 1 {
            return UIImage(named: name)
        }
        let filename = components.last
        components.removeLast()
        let dir = components.joinWithSeparator("/")
        if let path = NSBundle.mainBundle().pathForResource(filename, ofType: nil, inDirectory: dir) {
            //NSLog("ScriptParset \(path)")
            return UIImage(contentsOfFile: path)
        }
        return nil
    }

    static func imageSourceWith(name:String) -> CGImageSource? {
        var components = name.componentsSeparatedByString("/")
        let url:URL?
        if components.count == 1 {
            url = NSBundle.mainBundle().URLForResource(name, withExtension: nil)
        } else {
            let filename = components.last
            components.removeLast()
            let dir = components.joinWithSeparator("/")
            url = NSBundle.mainBundle().URLForResource(filename!, withExtension: nil, subdirectory: dir)
        }
        if let urlImage = url {
            return CGImageSourceCreateWithURL(urlImage, nil)
        }
        return nil
    }
    */

    static let regexPercent = try! NSRegularExpression(pattern: "^[0-9\\.]+%$", options: NSRegularExpression.Options.caseInsensitive)

    static func parsePercent(_ value:String, full:CGFloat, defaultValue:CGFloat) -> CGFloat {
        let num = regexPercent.numberOfMatches(in: value, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, value.characters.count))
        if num == 1 {
            return CGFloat((value as NSString).floatValue / 100.0) * full
        }
        return defaultValue
    }

    static func parsePercentAny(_ value:Any, full:CGFloat, defaultValue:CGFloat) -> CGFloat? {
        if let f = value as? CGFloat {
            return f
        } else if let str = value as? String {
            return SwipeParser.parsePercent(str, full: full, defaultValue: defaultValue)
        }
        return nil
    }
    
    static func parseFont(_ value:Any?, scale:CGSize, full:CGFloat) -> UIFont {
        let fontSize = parseFontSize(value, full: full, defaultValue: 20, markdown: true)
        let fontNames = parseFontName(value, markdown: true)
        for name in fontNames {
            if let font = UIFont(name: name, size: fontSize * scale.height) {
                return font
            }
        }
        return UIFont.systemFont(ofSize: fontSize * scale.height)
    }
    
    static func parseFontSize(_ value:Any?, full:CGFloat, defaultValue:CGFloat, markdown:Bool) -> CGFloat {
        let key = markdown ? "size" : "fontSize"
        if let info = value as? [String:Any] {
            if let sizeValue = info[key] as? CGFloat {
                return sizeValue
            } else if let percent = info[key] as? String {
                return SwipeParser.parsePercent(percent, full: full, defaultValue: defaultValue)
            }
        }
        return defaultValue
    }
    
    static func parseFontName(_ value:Any?, markdown:Bool) -> [String] {
        let key = markdown ? "name" : "fontName"
        if let info = value as? [String:Any] {
            if let name = info[key] as? String {
                return [name]
            } else if let names = info[key] as? [String] {
                return names
            }
        }
        return []
    }
    
    static func parseShadow(_ value:Any?, scale:CGSize) -> NSShadow {
        let shadow = NSShadow()
        if let info = value as? [String:Any] {
            shadow.shadowOffset = SwipeParser.parseSize(info["offset"], defaultValue: CGSize(width: 1.0, height: 1.0), scale:scale)
            shadow.shadowBlurRadius = SwipeParser.parseCGFloat(info["radius"], defaultValue: 2) * scale.width
            shadow.shadowColor = UIColor(cgColor: SwipeParser.parseColor(info["color"], defaultColor: UIColor.black.cgColor))
        }
        return shadow
    }

    static func localizedString(_ params:[String:Any], langId:String?) -> String? {
        if let key = langId,
            let text = params[key] as? String {
            return text
        } else if let text = params["*"] as? String {
            return text
        }
        return nil
    }
}
