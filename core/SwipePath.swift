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

    private static let regexSVG = try! RegularExpression(pattern: "[a-z][0-9\\-\\.,\\s]*", options: RegularExpression.Options.caseInsensitive)
    private static let regexNUM = try! RegularExpression(pattern: "[\\-]*[0-9\\.]+", options: RegularExpression.Options())
    
    static func parse(_ shape:AnyObject?, w:CGFloat, h:CGFloat, scale:CGSize) -> CGPath? {
        if let string = shape as? String {
            if string == "ellipse" {
                return CGPath(ellipseIn: CGRect(x: 0, y: 0, width: w * scale.width, height: h * scale.height), transform: nil)
            } else {
                //NSLog("SwipePath \(string)")
                let matches = SwipePath.regexSVG.matches(in: string, options: RegularExpression.MatchingOptions(), range: NSMakeRange(0, string.characters.count))
                //NSLog("SwipePath \(matches)")
                let path = CGMutablePath()
                var pt = CGPoint.zero
                var cp = CGPoint.zero // last control point for S command
                var prevIndex = string.startIndex // for performance
                var prevOffset = 0
                for match in matches {
                    var start = <#T##Collection corresponding to `prevIndex`##Collection#>.index(prevIndex, offsetBy: match.range.location - prevOffset)
                    let cmd = string[start..<<#T##Collection corresponding to `start`##Collection#>.index(start, offsetBy: 1)]
                    start = <#T##Collection corresponding to `start`##Collection#>.index(start, offsetBy: 1)
                    let end = <#T##Collection corresponding to `start`##Collection#>.index(start, offsetBy: match.range.length-1)
                    prevIndex = end
                    prevOffset = match.range.location + match.range.length
                    
                    let params = string[start..<end]
                    let nums = SwipePath.regexNUM.matches(in: params, options: [], range: NSMakeRange(0, params.characters.count))
                    let p = nums.map({ (num) -> CGFloat in
                        let start = params.characters.index(params.startIndex, offsetBy: num.range.location)
                        let end = <#T##String.CharacterView corresponding to `start`##String.CharacterView#>.index(start, offsetBy: num.range.length)
                        return CGFloat((params[start..<end] as NSString).floatValue)
                    })
                    //NSLog("SwipeElement \(cmd) \(p) #\(p.count)")
                    switch(cmd) {
                    case "m":
                        if p.count == 2 {
                            path.moveTo(nil, x: pt.x+p[0], y: pt.y+p[1])
                            pt.x += p[0]
                            pt.y += p[1]
                        }
                    case "M":
                        if p.count == 2 {
                            path.moveTo(nil, x: p[0], y: p[1])
                            pt.x = p[0]
                            pt.y = p[1]
                        }
                    case "z":
                        path.closeSubpath()
                        break
                    case "Z":
                        path.closeSubpath()
                        break
                    case "c":
                        var i = 0
                        while(p.count >= i+6) {
                            path.addCurve(nil, cp1x: pt.x+p[i], cp1y: pt.y+p[i+1], cp2x: pt.x+p[i+2], cp2y: pt.y+p[i+3], endingAtX: pt.x+p[i+4], y: pt.y+p[i+5])
                            cp.x = pt.x+p[i+2]
                            cp.y = pt.y+p[i+3]
                            pt.x += p[i+4]
                            pt.y += p[i+5]
                            i += 6
                        }
                    case "C":
                        var i = 0
                        while(p.count >= i+6) {
                            path.addCurve(nil, cp1x: p[i], cp1y: p[i+1], cp2x: p[i+2], cp2y: p[i+3], endingAtX: p[i+4], y: p[i+5])
                            cp.x = p[i+2]
                            cp.y = p[i+3]
                            pt.x = p[i+4]
                            pt.y = p[i+5]
                            i += 6
                        }
                    case "s":
                        var i = 0
                        while(p.count >= i+4) {
                            path.addCurve(nil, cp1x: pt.x * 2 - cp.x, cp1y: pt.y * 2 - cp.y, cp2x: pt.x+p[i], cp2y: pt.y+p[i+1], endingAtX: pt.x+p[i+2], y: pt.y+p[i+3])
                            cp.x = pt.x + p[i]
                            cp.y = pt.y + p[i+1]
                            pt.x += p[i+2]
                            pt.y += p[i+3]
                            i += 4
                        }
                    case "S":
                        var i = 0
                        while(p.count >= i+4) {
                            path.addCurve(nil, cp1x: pt.x * 2 - cp.x, cp1y: pt.y * 2 - cp.y, cp2x: p[i], cp2y: p[i+1], endingAtX: p[i+2], y: p[i+3])
                            cp.x = p[i]
                            cp.y = p[i+1]
                            pt.x = p[i+2]
                            pt.y = p[i+3]
                            i += 4
                        }
                    case "l":
                        var i = 0
                        while(p.count >= i+2) {
                            path.addLineTo(nil, x: pt.x+p[i], y: pt.y+p[i+1])
                            pt.x += p[i]
                            pt.y += p[i+1]
                            i += 2
                        }
                    case "L":
                        var i = 0
                        while(p.count >= i+2) {
                            path.addLineTo(nil, x: p[i], y: p[i+1])
                            pt.x = p[i]
                            pt.y = p[i+1]
                            i += 2
                        }
                    case "v":
                        var i = 0
                        while(p.count >= i+1) {
                            path.addLineTo(nil, x: pt.x, y: pt.y+p[i])
                            pt.y += p[i]
                            i += 1
                        }
                    case "V":
                        var i = 0
                        while(p.count >= i+1) {
                            path.addLineTo(nil, x: pt.x, y: p[i])
                            pt.y = p[i]
                            i += 1
                        }
                    case "h":
                        var i = 0
                        while(p.count >= i+1) {
                            path.addLineTo(nil, x: pt.x+p[i], y: pt.y)
                            pt.x += p[i]
                            i += 1
                        }
                    case "H":
                        var i = 0
                        while(p.count >= i+1) {
                            path.addLineTo(nil, x: p[i], y: pt.y)
                            pt.x = p[i]
                            i += 1
                        }
                    default:
                        NSLog("SwipeElement ### unkwnown \(cmd)")
                        break;
                    }
                }
                var xform = CGAffineTransform(scaleX: scale.width, y: scale.height)
                return path.copy(using: &xform)
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
