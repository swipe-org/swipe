//
//  SwipePath.swift
//  Swipe
//
//  Created by satoshi on 10/1/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

class SwipePath {

    private static let regexSVG = try! NSRegularExpression(pattern: "[a-z][0-9\\-\\.,\\s]*", options: NSRegularExpressionOptions.CaseInsensitive)
    private static let regexNUM = try! NSRegularExpression(pattern: "[\\-]*[0-9\\.]+", options: NSRegularExpressionOptions())
    
    static func parse(shape:AnyObject?, w:CGFloat, h:CGFloat, scale:CGSize) -> CGPathRef? {
        if let string = shape as? String {
            if string == "ellipse" {
                return CGPathCreateWithEllipseInRect(CGRectMake(0, 0, w * scale.width, h * scale.height), nil)
            } else {
                //NSLog("SwipePath \(string)")
                let matches = SwipePath.regexSVG.matchesInString(string, options: NSMatchingOptions(), range: NSMakeRange(0, string.characters.count))
                //NSLog("SwipePath \(matches)")
                let path = CGPathCreateMutable()
                var pt = CGPointZero
                var cp = CGPointZero // last control point for S command
                var prevIndex = string.startIndex // for performance
                var prevOffset = 0
                for match in matches {
                    var start = prevIndex.advancedBy(match.range.location - prevOffset)
                    let cmd = string[start..<start.advancedBy(1)]
                    start = start.advancedBy(1)
                    let end = start.advancedBy(match.range.length-1)
                    prevIndex = end
                    prevOffset = match.range.location + match.range.length
                    
                    let params = string[start..<end]
                    let nums = SwipePath.regexNUM.matchesInString(params, options: [], range: NSMakeRange(0, params.characters.count))
                    let p = nums.map({ (num) -> CGFloat in
                        let start = params.startIndex.advancedBy(num.range.location)
                        let end = start.advancedBy(num.range.length)
                        return CGFloat((params[start..<end] as NSString).floatValue)
                    })
                    //NSLog("SwipeElement \(cmd) \(p) #\(p.count)")
                    switch(cmd) {
                    case "m":
                        if p.count == 2 {
                            CGPathMoveToPoint(path, nil, pt.x+p[0], pt.y+p[1])
                            pt.x += p[0]
                            pt.y += p[1]
                        }
                    case "M":
                        if p.count == 2 {
                            CGPathMoveToPoint(path, nil, p[0], p[1])
                            pt.x = p[0]
                            pt.y = p[1]
                        }
                    case "z":
                        CGPathCloseSubpath(path)
                        break
                    case "Z":
                        CGPathCloseSubpath(path)
                        break
                    case "c":
                        var i = 0
                        while(p.count >= i+6) {
                            CGPathAddCurveToPoint(path, nil, pt.x+p[i], pt.y+p[i+1], pt.x+p[i+2], pt.y+p[i+3], pt.x+p[i+4], pt.y+p[i+5])
                            cp.x = pt.x+p[i+2]
                            cp.y = pt.y+p[i+3]
                            pt.x += p[i+4]
                            pt.y += p[i+5]
                            i += 6
                        }
                    case "C":
                        var i = 0
                        while(p.count >= i+6) {
                            CGPathAddCurveToPoint(path, nil, p[i], p[i+1], p[i+2], p[i+3], p[i+4], p[i+5])
                            cp.x = p[i+2]
                            cp.y = p[i+3]
                            pt.x = p[i+4]
                            pt.y = p[i+5]
                            i += 6
                        }
                    case "q":
                        var i = 0
                        while(p.count >= i+4) {
                            CGPathAddQuadCurveToPoint(path, nil, pt.x+p[i], pt.y+p[i+1], pt.x+p[i+2], pt.y+p[i+3])
                            cp.x = pt.x+p[i]
                            cp.y = pt.y+p[i+1]
                            pt.x += p[i+2]
                            pt.y += p[i+3]
                            i += 4
                        }
                    case "Q":
                        var i = 0
                        while(p.count >= i+4) {
                            CGPathAddQuadCurveToPoint(path, nil, p[i], p[i+1], p[i+2], p[i+3])
                            cp.x = p[i]
                            cp.y = p[i+1]
                            pt.x = p[i+2]
                            pt.y = p[i+3]
                            i += 4
                        }
                    case "s":
                        var i = 0
                        while(p.count >= i+4) {
                            CGPathAddCurveToPoint(path, nil, pt.x * 2 - cp.x, pt.y * 2 - cp.y, pt.x+p[i], pt.y+p[i+1], pt.x+p[i+2], pt.y+p[i+3])
                            cp.x = pt.x + p[i]
                            cp.y = pt.y + p[i+1]
                            pt.x += p[i+2]
                            pt.y += p[i+3]
                            i += 4
                        }
                    case "S":
                        var i = 0
                        while(p.count >= i+4) {
                            CGPathAddCurveToPoint(path, nil, pt.x * 2 - cp.x, pt.y * 2 - cp.y, p[i], p[i+1], p[i+2], p[i+3])
                            cp.x = p[i]
                            cp.y = p[i+1]
                            pt.x = p[i+2]
                            pt.y = p[i+3]
                            i += 4
                        }
                    case "l":
                        var i = 0
                        while(p.count >= i+2) {
                            CGPathAddLineToPoint(path, nil, pt.x+p[i], pt.y+p[i+1])
                            pt.x += p[i]
                            pt.y += p[i+1]
                            i += 2
                        }
                    case "L":
                        var i = 0
                        while(p.count >= i+2) {
                            CGPathAddLineToPoint(path, nil, p[i], p[i+1])
                            pt.x = p[i]
                            pt.y = p[i+1]
                            i += 2
                        }
                    case "v":
                        var i = 0
                        while(p.count >= i+1) {
                            CGPathAddLineToPoint(path, nil, pt.x, pt.y+p[i])
                            pt.y += p[i]
                            i += 1
                        }
                    case "V":
                        var i = 0
                        while(p.count >= i+1) {
                            CGPathAddLineToPoint(path, nil, pt.x, p[i])
                            pt.y = p[i]
                            i += 1
                        }
                    case "h":
                        var i = 0
                        while(p.count >= i+1) {
                            CGPathAddLineToPoint(path, nil, pt.x+p[i], pt.y)
                            pt.x += p[i]
                            i += 1
                        }
                    case "H":
                        var i = 0
                        while(p.count >= i+1) {
                            CGPathAddLineToPoint(path, nil, p[i], pt.y)
                            pt.x = p[i]
                            i += 1
                        }
                    default:
                        NSLog("SwipeElement ### unknown \(cmd)")
                        break;
                    }
                }
                var xform = CGAffineTransformMakeScale(scale.width, scale.height)
                return CGPathCreateCopyByTransformingPath(path, &xform)
            }
        }
        return nil
    }
    
    /*
    //
    // This code was written before the SVG-compatible path description
    //
    private func parsePoints(points:[[CGFloat]]) -> CGMutablePathRef {
        let path = CGPathCreateMutable()
        var closed = true
        for p in points {
            switch (p.count) {
            case 0:
                CGPathCloseSubpath(path)
                closed = true
            case 2:
                if closed {
                    CGPathMoveToPoint(path, nil, p[0], p[1])
                    closed = false
                } else {
                    CGPathAddLineToPoint(path, nil, p[0], p[1])
                }
            case 4:
                CGPathAddQuadCurveToPoint(path, nil, p[0], p[1], p[2], p[3])
                closed = false
            case 6:
                CGPathAddCurveToPoint(path, nil, p[0], p[1], p[2], p[3], p[4], p[5])
                closed = false
            default:
                break;
            }
        }
        return path
    }
    */
}
