//
//  SwipeMarkdown.swift
//  Swipe
//
//  Created by satoshi on 9/21/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//
#if os(OSX)
import Cocoa
#else
import UIKit
#endif

class SwipeMarkdown {
    private var attrs = [String:[String:AnyObject]]()
    private var prefixes = [
        "-":"\u{2022} ", // bullet (U+2022), http://graphemica.com/%E2%80%A2
        "```":" ",
    ]
    private let scale:CGSize
    private var shadow:NSShadow?

    func attributesWith(fontSize:CGFloat, paragraphSpacing:CGFloat, fontName:String? = nil) -> [String:AnyObject] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = NSLineBreakMode.ByWordWrapping
        style.paragraphSpacing = paragraphSpacing * scale.height
        var font = UIFont.systemFontOfSize(fontSize * scale.height)
        if let name = fontName,
           let namedFont = UIFont(name: name, size: fontSize * scale.height) {
            font = namedFont
        }
        var attrs = [NSFontAttributeName: font, NSParagraphStyleAttributeName: style]
        if let shadow = self.shadow {
            attrs[NSShadowAttributeName] = shadow
        }
        return attrs
    }

    // Use function instead of lazy initializer to work around a probable bug in Swift
    private func genAttrs() -> [String:[String:AnyObject]] {
        return [
            "#": self.attributesWith(32, paragraphSpacing: 16),
            "##": self.attributesWith(28, paragraphSpacing: 14),
            "###": self.attributesWith(24, paragraphSpacing: 12),
            "####": self.attributesWith(22, paragraphSpacing: 11),
            "*": self.attributesWith(20, paragraphSpacing: 10),
            "-": self.attributesWith(20, paragraphSpacing: 5),
            "```": self.attributesWith(14, paragraphSpacing: 0, fontName: "Courier"),
            "```+": self.attributesWith(7, paragraphSpacing: 0, fontName: "Courier"),
        ]
    }
    
    init(info:[String:AnyObject]?, scale:CGSize, dimension:CGSize) {
        self.scale = scale
        if let params = info {
            shadow = SwipeParser.parseShadow(params["shadow"], scale: scale)
        }
        attrs = genAttrs()

        if let markdownInfo = info,
           let styles = markdownInfo["styles"] as? [String:AnyObject] {
            for (keyMark, value) in styles {
                if let attrInfo = value as? [String:AnyObject] {
                    var attrCopy:[String:AnyObject]
                    if let attr = attrs[keyMark] {
                        attrCopy = attr
                    } else {
                        attrCopy = self.attributesWith(20, paragraphSpacing: 10)
                    }
                    let styleCopy = NSMutableParagraphStyle()
                    if let style = attrCopy[NSParagraphStyleAttributeName] as? NSParagraphStyle {
                        // WARNING: copy all properties
                        styleCopy.lineBreakMode = style.lineBreakMode
                        styleCopy.paragraphSpacing = style.paragraphSpacing
                    }
                    
                    for (keyAttr, attrValue) in attrInfo {
                        switch(keyAttr) {
                        case "color":
                            // the value MUST be UIColor or NSColor, not CGColor
                            attrCopy[NSForegroundColorAttributeName] = UIColor(CGColor:SwipeParser.parseColor(attrValue))
                        case "font":
                            attrCopy[NSFontAttributeName] = SwipeParser.parseFont(attrValue, scale:scale, full:dimension.height)
                        case "prefix":
                            if let prefix = attrValue as? String {
                                prefixes[keyMark] = prefix
                            }
                        case "alignment":
                            if let alignment = attrValue as? String {
                                switch(alignment) {
                                case "center":
                                    styleCopy.alignment = .Center
                                case "right":
                                    styleCopy.alignment = .Right
                                case "left":
                                    styleCopy.alignment = .Left
                                default:
                                    break
                                }
                            }
                            break
                        /*
                        // iOS does not allow us to mix multiple shadows
                        case "shadow":
                            attr[NSShadowAttributeName] = SwipeParser.parseShadow(attrValue, scale: scale)
                        */
                        default:
                            break;
                        }
                    }
                    attrCopy[NSParagraphStyleAttributeName] = styleCopy
                    attrs[keyMark] = attrCopy
                }
            }
        }
    }

    func parse(markdowns:[String]) -> NSAttributedString {
        let strs = NSMutableAttributedString()
        var fCode = false
        for (index, markdown) in markdowns.enumerate() {
            var (key, body):(String?, String) = {
                if markdown == "```" {
                    fCode = !fCode
                    return fCode ? (nil, "") : ("```+", "")
                } else if fCode {
                    return ("```", markdown)
                } else {
                    for prefix in attrs.keys {
                        let result = markdown.commonPrefixWithString(prefix + " ", options: NSStringCompareOptions.LiteralSearch)
                        if result == prefix + " " {
                            return (prefix, markdown.substringFromIndex(markdown.startIndex.advancedBy(prefix.characters.count + 1)))
                        }
                    }
                }
                return ("*", markdown)
            }()

            if let keyPrefix = key {
                if let prefix = prefixes[keyPrefix] {
                    body = prefix + body
                }
                body += ((index < markdowns.count - 1) ? "\n" : "")
                strs.appendAttributedString(NSMutableAttributedString(string: body, attributes: attrs[keyPrefix]))
            }
        }
        //NSLog("Markdown:parse \(strs)")
        return strs
    }
}
