//
//  SwipeElement.swift
//  Swipe
//
//  Created by satoshi on 8/10/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
public typealias UIView = NSView
public typealias UIButton = NSButton
public typealias UIScreen = NSScreen
#else
import UIKit
#endif

import AVFoundation
import ImageIO
import CoreText

private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

protocol SwipeElementDelegate:NSObjectProtocol {
    func prototypeWith(name:String?) -> [String:AnyObject]?
    func pathWith(name:String?) -> AnyObject?
    func shouldRepeat(element:SwipeElement) -> Bool
    func onAction(element:SwipeElement)
    func didStartPlaying(element:SwipeElement)
    func didFinishPlaying(element:SwipeElement, completed:Bool)
    func parseMarkdown(element:SwipeElement, markdowns:[String]) -> NSAttributedString
    func baseURL() -> NSURL?
    func map(url:NSURL) -> NSURL?
    func pageIndex() -> Int // for debugging
    func localizedStringForKey(key:String) -> String?
    func languageIdentifier() -> String?
}

class SwipeElement:NSObject {
    // Debugging
    static var objectCount = 0
    private let pageIndex:Int
    
    // public properties
    weak var delegate:SwipeElementDelegate!
    var action:String?

    private var view:UIView?
    private var layer:CALayer?
    private var elements = [SwipeElement]()
    private var btn:UIButton?
    private let info:[String:AnyObject]
    private let scale:CGSize
    private var repeatCount = CGFloat(1.0)
    private let blackColor = UIColor.blackColor().CGColor
    private let whiteColor = UIColor.whiteColor().CGColor
#if os(OSX)
    private let contentScale = CGFloat(1.0) // REVIEW
#else
    private let contentScale = UIScreen.mainScreen().scale
#endif
    private var fRepeat = false
    
    // Image Element Specific
    private var imageLayer:CALayer?
    
    // Text Element Specific
    private var textLayer:CATextLayer?
    
    // Shape Element Specific
    private var shapeLayer:CAShapeLayer?
    
    // Video Element Specific
    private var videoPlayer:AVPlayer?
    private var fNeedRewind = false
    private var fSeeking = false
    private var pendingOffset:CGFloat?
    private var fPlaying = false
    private var videoStart = CGFloat(0.0)
    private var videoDuration = CGFloat(1.0)

    // Sprite Element Specific
    private var spriteLayer:CALayer?
    private var slice = CGSizeMake(1.0, 1.0)
    private var contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0)
    private var step = -1 // invalid to start
    private var slot = CGPointMake(0.0, 0.0) // actually Ints
    //private var dir:(Int, Int)?
    
#if os(iOS)
    // HTML Specific
    //private var webView:WKWebView?
#endif
    
    // Lazy properties
    private lazy var notificationManager = SNNotificationManager()

    init(info:[String:AnyObject], scale:CGSize, delegate:SwipeElementDelegate) {
        var template = info["template"] as? String
        if template == nil {
            template = info["element"] as? String
            if template != nil {
                MyLog("SwElement DEPRECATED element; use 'template'")
            }
        }
        let elementInfo = SwipeParser.inheritProperties(info, baseObject: delegate.prototypeWith(template))
        self.info = elementInfo
        self.scale = scale
        self.delegate = delegate
        self.pageIndex = delegate.pageIndex() // only for debugging
        super.init()
        self.setTimeOffsetTo(0.0)
        
        SwipeElement.objectCount += 1
        MyLog("SWElem init \(pageIndex) \(scale.width)", level:1)
    }
    
    deinit {
#if os(iOS)
/*
        if let webView = self.webView {
            webView.removeFromSuperview()
            SwipeWebViewPool.sharedInstance().storeWebView(webView)
            self.webView = nil
        }
*/
#endif
    
        SwipeElement.objectCount -= 1
        MyLog("SWElem deinit \(pageIndex) \(scale.width)", level: 1)
        if (SwipeElement.objectCount == 0) {
            MyLog("SWElem zero object!", level:1)
        }
    }
    
    static func checkMemoryLeak() {
        //assert(SwipeElement.objectCount == 0)
        if SwipeElement.objectCount > 0 {
            NSLog("SWElem  memory leak detected ###")
        }
    }
    
    private func valueFrom(info:[NSObject:AnyObject], key:String, defaultValue:CGFloat) -> CGFloat {
        if let value = info[key] as? CGFloat {
            return value
        }
        return defaultValue
    }

    private func booleanValueFrom(info:[NSObject:AnyObject], key:String, defaultValue:Bool) -> Bool {
        if let value = info[key] as? Bool {
            return value
        }
        return defaultValue
    }
    
    func loadView(dimension:CGSize) -> UIView? {
        return self.loadViewInternal(dimension, screenDimention: dimension)
    }
    
    // Returns the list of URLs of required resouces for this element (including children)
    lazy var resourceURLs:[NSURL:String] = {
        var urls = [NSURL:String]()
        let baseURL = self.delegate.baseURL()
        for (key, prefix) in ["img":"", "mask":"", "video":".mov", "sprite":""] {
            if let src = self.info[key] as? String,
                   url = NSURL.url(src, baseURL: baseURL) {
                if let fStream = self.info["stream"] as? Bool where fStream == true {
                    MyLog("SWElem no need to cache streaming video \(url)", level: 2)
                } else {
                    urls[url] = prefix
                }
            }
        }
        if let elementsInfo = self.info["elements"] as? [[String:AnyObject]] {
            let scaleDummy = CGSizeMake(1.0, 1.0)
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scaleDummy, delegate:self.delegate!)
                for (url, prefix) in element.resourceURLs {
                    urls[url] = prefix
                }
            }
        }
        return urls
    }()
    
    private func loadViewInternal(dimension:CGSize, screenDimention:CGSize) -> UIView? {
        let baseURL = delegate.baseURL()
        var x = CGFloat(0.0)
        var y = CGFloat(0.0)
        var w0 = dimension.width
        var h0 = dimension.height
        var fNaturalW = true
        var fNaturalH = true
        var imageRef:CGImage?
        var imageSrc:CGImageSourceRef?
        var maskSrc:CGImage?
        var pathSrc:CGPath?
        var innerLayer:CALayer? // for loop shift

        let fScaleToFill = info["w"] as? String == "fill" || info["h"] as? String == "fill"
        if fScaleToFill {
            w0 = dimension.width // we'll adjust it later
            h0 = dimension.height // we'll adjust it later
        } else {
            if let value = info["w"] as? CGFloat {
                w0 = value
                fNaturalW = false
            } else if let value = info["w"] as? String {
                w0 = SwipeParser.parsePercent(value, full: dimension.width, defaultValue: dimension.width)
                fNaturalW = false
            }
            if let value = info["h"] as? CGFloat {
                h0 = value
                fNaturalH = false
            } else if let value = info["h"] as? String {
                h0 = SwipeParser.parsePercent(value, full: dimension.height, defaultValue: dimension.height)
                fNaturalH = false
            }
        }
        
        if let src = info["img"] as? String {
            //imageSrc = SwipeParser.imageSourceWith(src)
            if let url = NSURL.url(src, baseURL: baseURL),
                   urlLocal = self.delegate.map(url),
                   imageS = CGImageSourceCreateWithURL(urlLocal, nil) {
                imageSrc = imageS
                if CGImageSourceGetCount(imageS) > 0 {
                    imageRef = CGImageSourceCreateImageAtIndex(imageS, 0, nil)
                } else {
                    imageSrc = nil
                }
            }
        }
        if let src = info["mask"] as? String {
            //maskSrc = SwipeParser.imageWith(src)
            if let url = NSURL.url(src, baseURL: baseURL),
                   urlLocal = self.delegate.map(url),
                   image = CGImageSourceCreateWithURL(urlLocal, nil) {
                if CGImageSourceGetCount(image) > 0 {
                    maskSrc = CGImageSourceCreateImageAtIndex(image, 0, nil)
                }
            }
        }

        pathSrc = parsePath(info["path"], w: w0, h: h0, scale:scale)

        // The natural size is determined by the contents (either image or mask)
        var sizeContents:CGSize?
        if imageRef != nil {
            sizeContents = CGSizeMake(CGFloat(CGImageGetWidth(imageRef)),
                                      CGFloat(CGImageGetHeight(imageRef)))
        } else if maskSrc != nil {
            sizeContents = CGSizeMake(CGFloat(CGImageGetWidth(maskSrc)),
                                      CGFloat(CGImageGetHeight(maskSrc)))
        } else  if let path = pathSrc {
            let rc = CGPathGetPathBoundingBox(path)
            sizeContents = CGSizeMake(rc.origin.x + rc.width, rc.origin.y + rc.height)
        }
        
        if let sizeNatural = sizeContents {
            if fScaleToFill {
                if w0 / sizeNatural.width * sizeNatural.height > h0 {
                    h0 = w0 / sizeNatural.width * sizeNatural.height
                } else {
                    w0 = h0 / sizeNatural.height * sizeNatural.width
                }
            } else if fNaturalW {
                if fNaturalH {
                    w0 = sizeNatural.width
                    h0 = sizeNatural.height
                } else {
                    w0 = h0 / sizeNatural.height * sizeNatural.width
                }
            } else {
                if fNaturalH {
                    h0 = w0 / sizeNatural.width * sizeNatural.height
                }
            }
        }
        
        if let value = info["x"] as? CGFloat {
            x = value
        } else if let value = info["x"] as? String {
            if value == "right" {
                x = dimension.width - w0
            } else if value == "left" {
                x = 0
            } else if value == "center" {
                x = (dimension.width - w0) / 2.0
            } else {
                x = SwipeParser.parsePercent(value, full: dimension.width, defaultValue: 0)
            }
        }
        if let value = info["y"] as? CGFloat {
            y = value
        } else if let value = info["y"] as? String {
            if value == "bottom" {
                y = dimension.height - h0
            } else if value == "top" {
                y = 0
            } else if value == "center" {
                y = (dimension.height - h0) / 2.0
            } else {
                y = SwipeParser.parsePercent(value, full: dimension.height, defaultValue: 0)
            }
        }
        //NSLog("SWEleme \(x),\(y),\(w0),\(h0),\(sizeContents),\(dimension),\(scale)")
        
        x *= scale.width
        y *= scale.height
        let w = w0 * scale.width
        let h = h0 * scale.height
        let frame = CGRectMake(x, y, w, h)
        
        let view = UIView(frame: frame)
#if os(OSX)
        let layer = view.makeBackingLayer()
#else
        let layer = view.layer
#endif
        self.layer = layer
        
        if let values = info["anchor"] as? [AnyObject] where values.count == 2 && w0 > 0 && h0 > 0,
           let posx = SwipeParser.parsePercentAny(values[0], full: w0, defaultValue: 0),
           let posy = SwipeParser.parsePercentAny(values[1], full: h0, defaultValue: 0) {
            layer.anchorPoint = CGPointMake(posx / w0, posy / h0)
        }
        
        if let values = info["pos"] as? [AnyObject] where values.count == 2,
           let posx = SwipeParser.parsePercentAny(values[0], full: dimension.width, defaultValue: 0),
           let posy = SwipeParser.parsePercentAny(values[1], full: dimension.height, defaultValue: 0) {
            layer.position = CGPointMake(posx * scale.width, posy * scale.height)
        }
        
        if let value = info["action"] as? String {
            action = value
#if os(iOS) // tvOS has some focus issue with UIButton, figure out OSX later
            let btn = UIButton(type: UIButtonType.Custom)
            btn.frame = view.bounds
            btn.addTarget(self, action: #selector(SwipeElement.buttonPressed), forControlEvents: UIControlEvents.TouchUpInside)
            btn.addTarget(self, action: #selector(SwipeElement.touchDown), forControlEvents: UIControlEvents.TouchDown)
            btn.addTarget(self, action: #selector(SwipeElement.touchUpOutside), forControlEvents: UIControlEvents.TouchUpOutside)
            view.addSubview(btn)
            self.btn = btn
#endif
            if action == "play" {
                notificationManager.addObserverForName(SwipePage.didStartPlaying, object: self.delegate, queue: NSOperationQueue.mainQueue()) {
                    /*[unowned self]*/ (_: NSNotification!) -> Void in
                    // NOTE: Animation does not work because we are performing animation using the parent layer
                    //UIView.animateWithDuration(0.2, animations: { () -> Void in
                        layer.opacity = 0.0
                    //})
                }
                notificationManager.addObserverForName(SwipePage.didFinishPlaying, object: self.delegate, queue: NSOperationQueue.mainQueue()) {
                    /*[unowned self]*/ (_: NSNotification!) -> Void in
                    // NOTE: Animation does not work because we are performing animation using the parent layer
                    //UIView.animateWithDuration(0.2, animations: { () -> Void in
                        layer.opacity = 1.0
                    //})
                }
            }
        }
        
        if let value = info["clip"] as? Bool {
            //view.clipsToBounds = value
            layer.masksToBounds = value
        }
        
        if let image = imageRef {
            let rc = view.bounds
            let imageLayer = CALayer()
            imageLayer.contentsScale = contentScale
            imageLayer.frame = rc
            imageLayer.contents = image
            imageLayer.contentsGravity = kCAGravityResizeAspectFill
            imageLayer.masksToBounds = true
            layer.addSublayer(imageLayer)
            if let tiling = info["tiling"] as? Bool where tiling {
                let hostLayer = CALayer()
                innerLayer = hostLayer
                //rc.origin = CGPointZero
                //imageLayer.frame = rc
                hostLayer.addSublayer(imageLayer)
                layer.addSublayer(hostLayer)
                layer.masksToBounds = true
            
                var rcs = [rc, rc, rc, rc]
                rcs[0].origin.x -= rc.size.width
                rcs[1].origin.x += rc.size.width
                rcs[2].origin.y -= rc.size.height
                rcs[3].origin.y += rc.size.height
                for rc in rcs {
                    let subLayer = CALayer()
                    subLayer.contentsScale = contentScale
                    subLayer.frame = rc
                    subLayer.contents = image
                    subLayer.contentsGravity = kCAGravityResizeAspectFill
                    subLayer.masksToBounds = true
                    hostLayer.addSublayer(subLayer)
                }
            }
            
            // Handling GIF animation
            if let isrc = imageSrc {
                self.step = 0
                var images = [CGImageRef]()
                // NOTE: Using non-main thread has some side-effect
                //let queue = dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0)
                //dispatch_async(queue) { () -> Void in
                    let count = CGImageSourceGetCount(isrc)
                    for i in 1..<count {
                        if let image = CGImageSourceCreateImageAtIndex(isrc, i, nil) {
                            images.append(image)
                        }
                    }
                    let ani = CAKeyframeAnimation(keyPath: "contents")
                    ani.values = images
                    ani.beginTime = 1e-10
                    ani.duration = 1.0
                    ani.fillMode = kCAFillModeBoth
                    imageLayer.addAnimation(ani, forKey: "contents")
                //}
            }
            self.imageLayer = imageLayer
        }
        
#if os(iOS)
/*
        var htmlText = info["html"] as? String
        if let htmls = info["html"] as? [String] {
            htmlText = htmls.joinWithSeparator("\n")
        }
        if let html = htmlText {
            let webview = SwipeWebViewPool.sharedInstance().getWebView()
            webview.frame = view.bounds
            webview.opaque = false
            webview.backgroundColor = UIColor.clearColor()
            webview.userInteractionEnabled = false
            let header = "<head><meta name='viewport' content='initial-scale=\(scale.width), user-scalable=no, width=\(Int(w0))'></head>"
            let style:String
            if let value = self.delegate.styleWith(info["style"] as? String) {
                style = "<style>\(value)</style>"
            } else {
                style = ""
            }
            webview.loadHTMLString("<html>\(header)\(style)<body>\(html)</body></html>", baseURL: nil)
            view.addSubview(webview)

            self.webView = webview
        }
*/
#endif
        
        if let src = info["sprite"] as? String,
           let slice = info["slice"] as? [Int] {
            //view.clipsToBounds = true
            layer.masksToBounds = true
            if let values = self.info["slot"] as? [Int] where values.count == 2 {
                slot = CGPointMake(CGFloat(values[0]), CGFloat(values[1]))
            }
            if let url = NSURL.url(src, baseURL: baseURL),
                   urlLocal = self.delegate.map(url),
                   imageSource = CGImageSourceCreateWithURL(urlLocal, nil) where CGImageSourceGetCount(imageSource) > 0,
               let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                let imageLayer = CALayer()
                imageLayer.contentsScale = contentScale
                imageLayer.frame = view.bounds
                imageLayer.contents = image
                if slice.count > 0 {
                    self.slice.width = CGFloat(slice[0])
                    if slice.count > 1 {
                        self.slice.height = CGFloat(slice[1])
                    }
                }
                contentsRect = CGRectMake(slot.x/self.slice.width, slot.y/self.slice.height, 1.0/self.slice.width, 1.0/self.slice.height)
                imageLayer.contentsRect = contentsRect
                layer.addSublayer(imageLayer)
                spriteLayer = imageLayer
            }
        }
        layer.backgroundColor = SwipeParser.parseColor(info["bc"])

        if let value = self.info["videoDuration"] as? CGFloat {
            videoDuration = value
        }
        if let value = self.info["videoStart"] as? CGFloat {
            videoStart = value
        }
        if let image = maskSrc {
            let imageLayer = CALayer()
            imageLayer.contentsScale = contentScale
            imageLayer.frame = CGRectMake(0,0,w,h)
            imageLayer.contents = image
            layer.mask = imageLayer
        }
        if let radius = info["cornerRadius"] as? CGFloat {
            layer.cornerRadius = radius * scale.width;
            //view.clipsToBounds = true;
        }

        if let borderWidth = info["borderWidth"] as? CGFloat {
            layer.borderWidth = borderWidth * scale.width
            layer.borderColor = SwipeParser.parseColor(info["borderColor"], defaultColor: blackColor)
        }
        
        if let path = pathSrc {
            let shapeLayer = CAShapeLayer()
            shapeLayer.contentsScale = contentScale
            if let xpath = SwipeParser.transformedPath(path, param: info, size:frame.size) {
                shapeLayer.path = xpath
            } else {
                shapeLayer.path = path
            }
            shapeLayer.fillColor = SwipeParser.parseColor(info["fillColor"])
            shapeLayer.strokeColor = SwipeParser.parseColor(info["strokeColor"], defaultColor: blackColor)
            shapeLayer.lineWidth = SwipeParser.parseCGFloat(info["lineWidth"]) * self.scale.width
            
            processShadow(info, layer: shapeLayer)

            shapeLayer.lineCap = "round"
            shapeLayer.strokeStart = SwipeParser.parseCGFloat(info["strokeStart"], defalutValue: 0.0)
            shapeLayer.strokeEnd = SwipeParser.parseCGFloat(info["strokeEnd"], defalutValue: 1.0)
            layer.addSublayer(shapeLayer)
            self.shapeLayer = shapeLayer
            if let tiling = info["tiling"] as? Bool where tiling {
                let hostLayer = CALayer()
                innerLayer = hostLayer
                let rc = view.bounds
                hostLayer.addSublayer(shapeLayer)
                layer.addSublayer(hostLayer)
                layer.masksToBounds = true
            
                var rcs = [rc, rc, rc, rc]
                rcs[0].origin.x -= rc.size.width
                rcs[1].origin.x += rc.size.width
                rcs[2].origin.y -= rc.size.height
                rcs[3].origin.y += rc.size.height
                for rc in rcs {
                    let subLayer = CAShapeLayer()
                    subLayer.frame = rc
                    subLayer.contentsScale = shapeLayer.contentsScale
                    subLayer.path = shapeLayer.path
                    subLayer.fillColor = shapeLayer.fillColor
                    subLayer.strokeColor = shapeLayer.strokeColor
                    subLayer.lineWidth = shapeLayer.lineWidth
                    subLayer.shadowColor = shapeLayer.shadowColor
                    subLayer.shadowOffset = shapeLayer.shadowOffset
                    subLayer.shadowOpacity = shapeLayer.shadowOpacity
                    subLayer.shadowRadius = shapeLayer.shadowRadius
                    subLayer.lineCap = shapeLayer.lineCap
                    subLayer.strokeStart = shapeLayer.strokeStart
                    subLayer.strokeEnd = shapeLayer.strokeEnd
                    hostLayer.addSublayer(subLayer)
                }
            }
            
        } else {
            processShadow(info, layer: layer)
        }
        
        var mds = info["markdown"]
        if let md = mds as? String {
            mds = [md]
        }
        if let markdowns = mds as? [String] {
#if !os(OSX) // REVIEW
            let attrString = self.delegate.parseMarkdown(self, markdowns: markdowns)
            let rcLabel = view.bounds
            let label = UILabel(frame: rcLabel)
            label.attributedText = attrString
            label.numberOfLines = 999
            view.addSubview(label)
#endif
        }
        
        if let text = parseText(info, key:"text") {
            SwipeElement.addTextLayer(text, scale:self.scale, info: info, dimension:screenDimention, layer: layer)
        }
        
        // http://stackoverflow.com/questions/9290972/is-it-possible-to-make-avurlasset-work-without-a-file-extension
        var fStream:Bool = {
            if let fStream = info["stream"] as? Bool {
                return fStream
            }
            return false
        }()
        let urlVideoOrRadio:NSURL? = {
            if let src = info["video"] as? String,
                let url = NSURL.url(src, baseURL: baseURL) {
                return url
            }
            if let src = info["radio"] as? String,
                let url = NSURL.url(src, baseURL: baseURL) {
                fStream = true
                return url
            }
            return nil
        }()
        if let url = urlVideoOrRadio {
            let videoPlayer = AVPlayer()
            self.videoPlayer = videoPlayer
            let videoLayer = AVPlayerLayer(player: videoPlayer)
            videoLayer.frame = CGRectMake(0.0, 0.0, w, h)
            if fScaleToFill {
                videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            }
            layer.addSublayer(videoLayer)

            let urlLocalOrStream:NSURL?
            if fStream {
                MyLog("SWElem stream=\(url)", level:2)
                urlLocalOrStream = url
            } else if let urlLocal = self.delegate.map(url) {
                urlLocalOrStream = urlLocal
            } else {
                urlLocalOrStream = nil
            }
            
            if let urlVideo = urlLocalOrStream {
                let playerItem = AVPlayerItem(URL: urlVideo)
                videoPlayer.replaceCurrentItemWithPlayerItem(playerItem)

                notificationManager.addObserverForName(AVPlayerItemDidPlayToEndTimeNotification, object: playerItem, queue: NSOperationQueue.mainQueue()) {
                    [unowned self] (_:NSNotification!) -> Void in
                    MyLog("SWElem play to end!", level: 1)
                    if self.delegate != nil && self.delegate!.shouldRepeat(self) {
                        videoPlayer.seekToTime(kCMTimeZero)
                        videoPlayer.play()
                    } else {
                        self.fNeedRewind = true
                        if self.fPlaying {
                            self.fPlaying = false
                            self.delegate.didFinishPlaying(self, completed:true)
                        }
                    }
                }
            }
            
            notificationManager.addObserverForName(SwipePage.shouldPauseAutoPlay, object: delegate, queue: NSOperationQueue.mainQueue()) {
                [unowned self] (_:NSNotification!) -> Void in
                if self.fPlaying {
                    self.fPlaying = false
                    self.delegate.didFinishPlaying(self, completed:false)
                    videoPlayer.pause()
                }
            }
            notificationManager.addObserverForName(SwipePage.shouldStartAutoPlay, object: delegate, queue: NSOperationQueue.mainQueue()) {
                [unowned self] (_:NSNotification!) -> Void in
                if !self.fPlaying && layer.opacity > 0 {
                    self.fPlaying = true
                    self.delegate.didStartPlaying(self)
                    MyLog("SWElem videoPlayer.state = \(videoPlayer.status.rawValue)", level: 1)
                    if self.fNeedRewind {
                        videoPlayer.seekToTime(kCMTimeZero)
                    }
                    videoPlayer.play()
                    self.fNeedRewind = false
                }
            }
        }
        
        if let transform = SwipeParser.parseTransform(info, scaleX:scale.width, scaleY:scale.height, base: nil, fSkipTranslate: false, fSkipScale: self.shapeLayer != nil) {
            layer.transform = transform
        }
        layer.opacity = SwipeParser.parseFloat(info["opacity"])
        
        if let to = info["to"] as? [String:AnyObject] {
            let start, duration:Double
            if let timing = to["timing"] as? [Double]
                where timing.count == 2 && timing[0] >= 0 && timing[0] <= timing[1] && timing[1] <= 1 {
                start = timing[0] == 0 ? 1e-10 : timing[0]
                duration = timing[1] - start
            } else {
                start = 1e-10
                duration = 1.0
            }
            var fSkipTranslate = false
            
            if let path = parsePath(to["pos"], w: w0, h: h0, scale:scale) {
                let pos = layer.position
                var xform = CGAffineTransformMakeTranslation(pos.x, pos.y)
                let ani = CAKeyframeAnimation(keyPath: "position")
                ani.path = CGPathCreateCopyByTransformingPath(path, &xform)
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                ani.calculationMode = kCAAnimationPaced
                if let mode = to["mode"] as? String {
                    switch(mode) {
                    case "auto":
                        ani.rotationMode = kCAAnimationRotateAuto
                    case "reverse":
                        ani.rotationMode = kCAAnimationRotateAutoReverse
                    default: // or "none"
                        ani.rotationMode = nil
                    }
                }
                layer.addAnimation(ani, forKey: "position")
                fSkipTranslate = true
            }

            if let transform = SwipeParser.parseTransform(to, scaleX:scale.width, scaleY:scale.height, base:info, fSkipTranslate: fSkipTranslate, fSkipScale: self.shapeLayer != nil) {
                let ani = CABasicAnimation(keyPath: "transform")
                ani.fromValue = NSValue(CATransform3D : layer.transform)
                ani.toValue = NSValue(CATransform3D : transform)
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.addAnimation(ani, forKey: "transform")
            }

            if let opacity = to["opacity"] as? Float {
                let ani = CABasicAnimation(keyPath: "opacity")
                ani.fromValue = layer.opacity
                ani.toValue = opacity
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.addAnimation(ani, forKey: "opacity")
            }
            
            if let backgroundColor:AnyObject = to["bc"] {
                let ani = CABasicAnimation(keyPath: "backgroundColor")
                ani.fromValue = layer.backgroundColor
                ani.toValue = SwipeParser.parseColor(backgroundColor)
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.addAnimation(ani, forKey: "backgroundColor")
            }
            if let borderColor:AnyObject = to["borderColor"] {
                let ani = CABasicAnimation(keyPath: "borderColor")
                ani.fromValue = layer.borderColor
                ani.toValue = SwipeParser.parseColor(borderColor)
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.addAnimation(ani, forKey: "borderColor")
            }
            if let borderWidth = to["borderWidth"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "borderWidth")
                ani.fromValue = layer.borderWidth
                ani.toValue = borderWidth * scale.width
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.addAnimation(ani, forKey: "borderWidth")
            }
            if let borderWidth = to["cornerRadius"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "cornerRadius")
                ani.fromValue = layer.cornerRadius
                ani.toValue = borderWidth * scale.width
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.addAnimation(ani, forKey: "cornerRadius")
            }
            
            if let textLayer = self.textLayer {
                if let textColor:AnyObject = to["textColor"] {
                    let ani = CABasicAnimation(keyPath: "foregroundColor")
                    ani.fromValue = textLayer.foregroundColor
                    ani.toValue = SwipeParser.parseColor(textColor)
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    textLayer.addAnimation(ani, forKey: "foregroundColor")
                }
            }
            if let srcs = to["img"] as? [String] {
                var images = [CGImage]()
                for src in srcs {
                    if let url = NSURL.url(src, baseURL: baseURL),
                           urlLocal = self.delegate.map(url),
                           image = CGImageSourceCreateWithURL(urlLocal, nil) {
                        if CGImageSourceGetCount(image) > 0 {
                            images.append(CGImageSourceCreateImageAtIndex(image, 0, nil)!)
                        }
                    }
                    //if let image = SwipeParser.imageWith(src) {
                        //images.append(image.CGImage!)
                    //}
                }
                if let imageLayer = self.imageLayer {
                    let ani = CAKeyframeAnimation(keyPath: "contents")
                    ani.values = images
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    imageLayer.addAnimation(ani, forKey: "contents")
                }
            }

            if let shapeLayer = self.shapeLayer {
                if let params = to["path"] as? [AnyObject] {
                    var values = [shapeLayer.path!]
                    for param in params {
                        if let path = parsePath(param, w: w0, h: h0, scale:scale) {
                            values.append(path)
                        }
                    }
                    let ani = CAKeyframeAnimation(keyPath: "path")
                    ani.values = values
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "path")
                } else if let path = parsePath(to["path"], w: w0, h: h0, scale:scale) {
                    let ani = CABasicAnimation(keyPath: "path")
                    ani.fromValue = shapeLayer.path
                    ani.toValue = path
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "path")
                } else if let path = SwipeParser.transformedPath(pathSrc!, param: to, size:frame.size) {
                    let ani = CABasicAnimation(keyPath: "path")
                    ani.fromValue = shapeLayer.path
                    ani.toValue = path
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "path")
                }
                if let fillColor:AnyObject = to["fillColor"] {
                    let ani = CABasicAnimation(keyPath: "fillColor")
                    ani.fromValue = shapeLayer.fillColor
                    ani.toValue = SwipeParser.parseColor(fillColor)
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "fillColor")
                }
                if let strokeColor:AnyObject = to["strokeColor"] {
                    let ani = CABasicAnimation(keyPath: "strokeColor")
                    ani.fromValue = shapeLayer.strokeColor
                    ani.toValue = SwipeParser.parseColor(strokeColor)
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "strokeColor")
                }
                if let lineWidth = to["lineWidth"] as? CGFloat {
                    let ani = CABasicAnimation(keyPath: "lineWidth")
                    ani.fromValue = shapeLayer.lineWidth
                    ani.toValue = lineWidth * scale.width
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "lineWidth")
                }
                if let strokeStart = to["strokeStart"] as? CGFloat {
                    let ani = CABasicAnimation(keyPath: "strokeStart")
                    ani.fromValue = shapeLayer.strokeStart
                    ani.toValue = strokeStart
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "strokeStart")
                }
                if let strokeEnd = to["strokeEnd"] as? CGFloat {
                    let ani = CABasicAnimation(keyPath: "strokeEnd")
                    ani.fromValue = shapeLayer.strokeEnd
                    ani.toValue = strokeEnd
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.addAnimation(ani, forKey: "strokeEnd")
                }
            }
        }
        
        if let fRepeat = info["repeat"] as? Bool where fRepeat {
            //NSLog("SE detected an element with repeat")
            self.fRepeat = fRepeat
            layer.speed = 0 // Independently animate it
        }
        
        if let animation = info["loop"] as? [NSObject:AnyObject],
           let style = animation["style"] as? String {
            //
            // Note: Use the inner layer (either image or shape) for the loop animation 
            // to avoid any conflict with other transformation if it is available.
            // In this case, the loop animation does not effect chold elements (because
            // we use UIView hierarchy instead of CALayer hierarchy.
            //
            // It means the loop animation on non-image/non-shape element does not work well
            // with other transformation.
            //
            var loopLayer = layer
            if let l = imageLayer {
                loopLayer = l
            } else if let l = shapeLayer {
                loopLayer = l
            }
            
            let start, duration:Double
            if let timing = animation["timing"] as? [Double]
                where timing.count == 2 && timing[0] >= 0 && timing[0] <= timing[1] && timing[1] <= 1 {
                start = timing[0] == 0 ? 1e-10 : timing[0]
                duration = timing[1] - start
            } else {
                start = 1e-10
                duration = 1.0
            }
            let repeatCount = Float(valueFrom(animation, key: "count", defaultValue: 1))
        
            switch(style) {
            case "vibrate":
                let delta = valueFrom(animation, key: "delta", defaultValue: 10.0)
                let ani = CAKeyframeAnimation(keyPath: "transform")
                ani.values = [NSValue(CATransform3D:loopLayer.transform),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeTranslation(delta, 0.0, 0.0), loopLayer.transform)),
                              NSValue(CATransform3D:loopLayer.transform),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeTranslation(-delta, 0.0, 0.0), loopLayer.transform)),
                              NSValue(CATransform3D:loopLayer.transform)]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.addAnimation(ani, forKey: "transform")
            case "shift":
                let shiftLayer = (innerLayer == nil) ? layer : innerLayer!
                let ani = CAKeyframeAnimation(keyPath: "transform")
                let shift:CGSize = {
                    if let dir = animation["direction"] as? String {
                        switch(dir) {
                        case "n":
                            return CGSizeMake(0, -h)
                        case "e":
                            return CGSizeMake(w, 0)
                        case "w":
                            return CGSizeMake(-w, 0)
                        default:
                            return CGSizeMake(0, h)
                        }
                    } else {
                        return CGSizeMake(0, h)
                    }
                }()
                ani.values = [NSValue(CATransform3D:shiftLayer.transform),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeTranslation(shift.width, shift.height, 0.0), shiftLayer.transform))]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                shiftLayer.addAnimation(ani, forKey: "transform")
            case "blink":
                let ani = CAKeyframeAnimation(keyPath: "opacity")
                ani.values = [1.0, 0.0, 1.0]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.addAnimation(ani, forKey: "opacity")
            case "spin":
                let fClockwise = booleanValueFrom(animation, key: "clockwise", defaultValue: true)
                let degree = (fClockwise ? 120 : -120) * CGFloat(M_PI / 180.0)
                let ani = CAKeyframeAnimation(keyPath: "transform")
                ani.values = [NSValue(CATransform3D:loopLayer.transform),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeRotation(degree, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeRotation(degree * 2, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeRotation(degree * 3, 0.0, 0.0, 1.0), loopLayer.transform))]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.addAnimation(ani, forKey: "transform")
            case "wiggle":
                let delta = valueFrom(animation, key: "delta", defaultValue: 15) * CGFloat(M_PI / 180.0)
                let ani = CAKeyframeAnimation(keyPath: "transform")
                ani.values = [NSValue(CATransform3D:loopLayer.transform),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeRotation(delta, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(CATransform3D:loopLayer.transform),
                              NSValue(CATransform3D:CATransform3DConcat(CATransform3DMakeRotation(-delta, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(CATransform3D:loopLayer.transform)]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.addAnimation(ani, forKey: "transform")
            case "path":
                if let shapeLayer = self.shapeLayer {
                    var values = [shapeLayer.path!]
                    if let params = animation["path"] as? [AnyObject] {
                        for param in params {
                            if let path = parsePath(param, w: w0, h: h0, scale:scale) {
                                values.append(path)
                            }
                        }
                    } else if let path = parsePath(animation["path"], w: w0, h: h0, scale:scale) {
                        values.append(path)
                    }
                    if values.count >= 2 {
                        values.append(shapeLayer.path!)
                        let ani = CAKeyframeAnimation(keyPath: "path")
                        ani.values = values
                        ani.repeatCount = repeatCount
                        ani.beginTime = start
                        ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                        ani.fillMode = kCAFillModeBoth
                        shapeLayer.addAnimation(ani, forKey: "path")
                    }
                }
            case "sprite":
                if let targetLayer = spriteLayer {
                    let ani = CAKeyframeAnimation(keyPath: "contentsRect")
                    let rc0 = CGRectMake(0, slot.y/self.slice.height, 1.0/self.slice.width, 1.0/self.slice.height)
                    ani.values = Array(0..<Int(slice.width)).map() { (index:Int) -> NSValue in
                        NSValue(CGRect: CGRect(origin: CGPointMake(CGFloat(index) / self.slice.width, rc0.origin.y), size: rc0.size))
                    }
                    ani.repeatCount = repeatCount
                    ani.beginTime = start
                    ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                    ani.fillMode = kCAFillModeBoth
                    ani.calculationMode = kCAAnimationDiscrete
                    targetLayer.addAnimation(ani, forKey: "contentsRect")
                }
                //self.dir = (1,0)
                //self.repeatCount = CGFloat(repeatCount)
            default:
                break
            }
        }
        
        // Nested Elements
        if let elementsInfo = info["elements"] as? [[String:AnyObject]] {
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scale, delegate:self.delegate!)
                if let subview = element.loadViewInternal(CGSizeMake(w0, h0), screenDimention: screenDimention) {
                    view.addSubview(subview)
                    elements.append(element)
                }
            }
        }

        self.view = view
        return view
    }

    // This function is called by SwipePage when unloading the view.
    // PARANOIA: Extra effort to clean up everything
    func clear() {
        notificationManager.clear()
    }

    private func parsePath(shape:AnyObject?, w:CGFloat, h:CGFloat, scale:CGSize) -> CGPathRef? {
        var shape0: AnyObject? = shape
        if let refs = shape as? [NSObject:AnyObject], key = refs["ref"] as? String {
            shape0 = delegate.pathWith(key)
        }
        return SwipePath.parse(shape0, w: w, h: h, scale: scale)
    }
    
    func buttonPressed() {
        MyLog("SWElem buttonPressed", level: 1)
        layer?.opacity = 1.0
        if let delegate = self.delegate {
            delegate.onAction(self)
        }
    }

    func touchDown() {
        MyLog("SWElem touchDown", level: 1)
        layer?.opacity = 0.5
    }
    
    func touchUpOutside() {
        MyLog("SWElem touchUpOutside", level: 1)
        layer?.opacity = 1.0
    }
    
    func setTimeOffsetTo(offset:CGFloat, fAutoPlay:Bool = false, fElementRepeat:Bool = false) {
        if offset < 0.0 || offset > 1.0 {
            return
        }
        
        if let layer = self.layer where layer.speed == 0 {
            // independently animated
            layer.timeOffset = CFTimeInterval(offset)
        }
        
        for element in elements {
            element.setTimeOffsetTo(offset, fAutoPlay: fAutoPlay, fElementRepeat: fElementRepeat)
        }
        
        if fElementRepeat && !self.fRepeat {
            return
        }
        
        // This block of code was replaced by CAKeyFrameAnimation (sprite)
        /*
        if let layer = spriteLayer, let _ = self.dir {
            let step:Int
            if offset == 1 && self.repeatCount == 1 {
                step = Int(self.slice.width) - 1 // always end at the last one if repeatCount==1
            } else {
                step = Int(offset * self.repeatCount * self.slice.width) % Int(self.slice.width)
            }
            if step != self.step /* || offset == 0.0 */ {
                contentsRect.origin.x = CGFloat(step) / self.slice.width
                contentsRect.origin.y = slot.y / self.slice.height
                layer.contentsRect = contentsRect
                self.step = step
            }
        }
        */
        
        if let player = self.videoPlayer {
            if fAutoPlay {
                return
            }
            if self.fSeeking {
                self.pendingOffset = offset
                return
            }
            let timeSec = videoStart + offset * videoDuration
            let time = CMTimeMakeWithSeconds(Float64(timeSec), 600)
            let tolerance = CMTimeMake(10, 600) // 1/60sec
            if player.status == AVPlayerStatus.ReadyToPlay {
                self.fSeeking = true
                SwipeElement.objectCount -= 1 // to avoid false memory leak detection
                player.seekToTime(time, toleranceBefore: tolerance, toleranceAfter: tolerance) { (_:Bool) -> Void in
                    assert(NSThread.currentThread() == NSThread.mainThread(), "thread error")
                    SwipeElement.objectCount += 1
                    self.fSeeking = false
                    if let pendingOffset = self.pendingOffset {
                        self.pendingOffset = nil
                        self.setTimeOffsetTo(pendingOffset, fAutoPlay: false, fElementRepeat: fElementRepeat)
                    }
                }
            }
        }
    }
    
/*
    func autoplay() {
        if let player = self.videoPlayer {
            if !fPlaying {
                fPlaying = true
                self.delegate?.didStartPlaying(self)
                player.play()
            }
        }
    }

    func pause() {
        if let player = self.videoPlayer {
            if fPlaying {
                fPlaying = false
                self.delegate?.didFinishPlaying(self)
                player.pause()
            }
        }
    }
*/
    func isVideoElement() -> Bool {
        if self.videoPlayer != nil {
            return true
        }
        for element in elements {
            if element.isVideoElement() {
                return true
            }
        }
        return false
    }
    
    func isRepeatElement() -> Bool {
        if fRepeat {
            return true
        }
        for element in elements {
            if element.isRepeatElement() {
                return true
            }
        }
        return false
    }

    func parseText(info:[String:AnyObject], key:String) -> String? {
        guard let value = info[key] else {
            return nil
        }
        if let text = value as? String {
            return text
        }
        guard let params = value as? [String:AnyObject] else {
            return nil
        }
        if let key = params["ref"] as? String,
               text = delegate.localizedStringForKey(key) {
            return text
        }
        return SwipeParser.localizedString(params, langId: delegate.languageIdentifier())
    }

    private func processShadow(info:[String:AnyObject], layer:CALayer) {
        if let shadowInfo = info["shadow"] as? [String:AnyObject] {
            layer.shadowColor = SwipeParser.parseColor(shadowInfo["color"], defaultColor: blackColor)
            layer.shadowOffset = SwipeParser.parseSize(shadowInfo["offset"], defalutValue: CGSizeMake(1, 1), scale:scale)
            layer.shadowOpacity = SwipeParser.parseFloat(shadowInfo["opacity"], defalutValue:0.5)
            layer.shadowRadius = SwipeParser.parseCGFloat(shadowInfo["radius"], defalutValue: 1.0) * self.scale.width
        }
    }
    
    static func addTextLayer(text:String, scale:CGSize, info:[String:AnyObject], dimension:CGSize, layer:CALayer) {
        var fTextBottom = false
        var fTextTop = false

        let paragraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = NSTextAlignment.Center
        paragraphStyle.lineBreakMode = NSLineBreakMode.ByWordWrapping
        
        func processAlignment(alignment:String) {
            switch(alignment) {
            case "left":
                paragraphStyle.alignment = NSTextAlignment.Left
            case "right":
                paragraphStyle.alignment = NSTextAlignment.Right
            case "justified":
                paragraphStyle.alignment = NSTextAlignment.Justified
            case "top":
                fTextTop = true
            case "bottom":
                fTextBottom = true
            default:
                break
            }
        }
        if let alignment = info["textAlign"] as? String {
            processAlignment(alignment)
        } else if let alignments = info["textAlign"] as? [String] {
            for alignment in alignments {
                processAlignment(alignment)
            }
        }
        let fontSize: CGFloat = {
            let defaultSize = 20.0 / 480.0 * dimension.height
            let size = SwipeParser.parseFontSize(info, full: dimension.height, defaultValue: defaultSize, markdown: false)
            return round(size * scale.height)
        }()
        let fontNames = SwipeParser.parseFontName(info, markdown: false)
        let font: UIFont = {
            for fontName in fontNames {
                if let font = UIFont(name: fontName, size: fontSize) {
                    return font
                }
            }
            return UIFont(name: "Helvetica", size: fontSize)!
        }()

        let attr:[String:AnyObject] = [
            NSFontAttributeName:font,
            NSForegroundColorAttributeName:UIColor(CGColor: SwipeParser.parseColor(info["textColor"], defaultColor: UIColor.blackColor().CGColor)),
            NSParagraphStyleAttributeName:paragraphStyle]
        let textStorage = NSTextStorage(string: text, attributes: attr)

        var rcText = layer.bounds
        UIGraphicsBeginImageContextWithOptions(rcText.size, false, 2); defer {
            UIGraphicsEndImageContext()
        }
        
        let manager = NSLayoutManager()
        textStorage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSizeMake(rcText.width, 99999))
        manager.addTextContainer(container)
        manager.ensureLayoutForTextContainer(container)
        let height = manager.usedRectForTextContainer(container).size.height
        if fTextBottom {
            rcText.origin.y = rcText.size.height - height
        } else if !fTextTop {
            rcText.origin.y =  (rcText.size.height - height) / 2
        }
        textStorage.drawInRect(rcText)
        layer.contents = UIGraphicsGetImageFromCurrentImageContext().CGImage
    }
    
    /*
    func isPlaying() -> Bool {
        if self.fPlaying {
            return true
        }
        for element in elements {
            if element.isPlaying() {
                return true
            }
        }
        return false
    }
    */
}
