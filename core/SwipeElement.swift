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

private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        print(text)
    }
}

// HACK:
// AVPlayerLayer causes a crash in deinit when it was rendered by presentationPlayer,
// which calls init(layer: Any) to create a copy before the rendering. 
// We can work-around this bug by calling super.init().
class XAVPlayerLayer: AVPlayerLayer {
    override init(layer: Any) {
        //print("XAVPlayerLayer init with layer")
        super.init() // HACK to avoid crash
    }
    init(player: AVPlayer) {
        super.init()
        self.player = player
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
    }
}

protocol SwipeElementDelegate:NSObjectProtocol {
    func prototypeWith(_ name:String?) -> [String:Any]?
    func pathWith(_ name:String?) -> Any?
    func shouldRepeat(_ element:SwipeElement) -> Bool
    func onAction(_ element:SwipeElement)
    func didStartPlaying(_ element:SwipeElement)
    func didFinishPlaying(_ element:SwipeElement, completed:Bool)
    func parseMarkdown(_ element:SwipeElement, markdowns:[String]) -> NSAttributedString
    func baseURL() -> URL?
    func map(_ url:URL) -> URL?
    func addedResourceURLs(_ urls:[URL:String], callback:@escaping () -> Void)
    func pageIndex() -> Int // for debugging
    func localizedStringForKey(_ key:String) -> String?
    func languageIdentifier() -> String?
}

class SwipeElement: SwipeView, SwipeViewDelegate {
    // Debugging
    static var objectCount = 0
    private let pageIndex:Int
    
    // public properties
    weak var delegate:SwipeElementDelegate!
    var action:String?

    private var layer:CALayer?
    private var btn:UIButton?
    private let scale:CGSize
    private var screenDimension = CGSize(width: 0, height: 0)
    private var repeatCount = CGFloat(1.0)
    private let blackColor = UIColor.black.cgColor
    private let whiteColor = UIColor.white.cgColor
#if os(OSX)
    private let contentScale = CGFloat(1.0) // REVIEW
#else
    private let contentScale = UIScreen.main.scale
#endif
    private var fRepeat = false
    var helper: SwipeView?  // Example: SwipeList
    
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
    private var videoDuration:CGFloat?
    private var hasObserver = false
    private let tolerance = CMTimeMake(10, 600) // 1/60sec

    // Sprite Element Specific
    private var spriteLayer:CALayer?
    private var slice = CGSize(width: 1.0, height: 1.0)
    private var contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
    private var step = -1 // invalid to start
    private var slot = CGPoint(x: 0.0, y: 0.0) // actually Ints
    //private var dir:(Int, Int)?
    
#if os(iOS)
    // HTML Specific
    //private var webView:WKWebView?
#endif
    
    // Lazy properties
    private lazy var notificationManager = SNNotificationManager()

    init(info:[String:Any], scale:CGSize, parent:SwipeNode, delegate:SwipeElementDelegate) {
        var template = info["template"] as? String
        if template == nil {
            template = info["element"] as? String
            if template != nil {
                MyLog("SwElement DEPRECATED element; use 'template'")
            }
        }
        self.scale = scale
        self.delegate = delegate
        self.pageIndex = delegate.pageIndex() // only for debugging
        let elementInfo = SwipeParser.inheritProperties(info, baseObject: delegate.prototypeWith(template))
        super.init(parent: parent, info: elementInfo)
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
    
    private func value<T:FloatingPoint>(from info:[String:Any], key:String, defaultValue:T) -> T {
        if let value = info[key] as? T {
            return value
        }
        return defaultValue
    }

    private func booleanValue(from info:[String:Any], key:String, defaultValue:Bool) -> Bool {
        if let value = info[key] as? Bool {
            return value
        }
        return defaultValue
    }
    
    func loadView(_ dimension:CGSize) -> UIView? {
        return self.loadViewInternal(dimension, screenDimension: dimension)
    }
    
    // Returns the list of URLs of required resources for this element (including children)
    lazy var resourceURLs:[URL:String] = {
        var urls = [URL:String]()
        let baseURL = self.delegate.baseURL()
        for (key, prefix) in ["img":"", "mask":"", "video":".mov", "sprite":""] {
            if let src = self.info[key] as? String,
                let url = URL.url(src, baseURL: baseURL) {
                if let fStream = self.info["stream"] as? Bool, fStream == true {
                    MyLog("SWElem no need to cache streaming video \(url)", level: 2)
                } else {
                    urls[url] = prefix
                }
            }
        }
        if let elementsInfo = self.info["elements"] as? [[String:Any]] {
            let scaleDummy = CGSize(width: 1.0, height: 1.0)
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scaleDummy, parent:self, delegate:self.delegate!)
                for (url, prefix) in element.resourceURLs {
                    urls[url] = prefix
                }
            }
        }
        if let listInfo = self.info["list"] as? [String:Any] {
            if let itemsInfo = listInfo["items"] as? [[String:Any]] {
                for itemInfo in itemsInfo {
                    if let elementsInfo = itemInfo["elements"] as? [[String:Any]] {
                        let scaleDummy = CGSize(width: 1.0, height: 1.0)
                        for e in elementsInfo {
                            let element = SwipeElement(info: e, scale:scaleDummy, parent:self, delegate:self.delegate!)
                            for (url, prefix) in element.resourceURLs {
                                urls[url] = prefix
                            }
                        }
                    }
                }
            }
        }
        return urls
    }()
    
    func loadViewInternal(_ dimension:CGSize, screenDimension:CGSize) -> UIView? {
        self.screenDimension = screenDimension
        let baseURL = delegate.baseURL()
        var x = CGFloat(0.0)
        var y = CGFloat(0.0)
        var w0 = dimension.width
        var h0 = dimension.height
        var fNaturalW = true
        var fNaturalH = true
        var imageRef:CGImage?
        var imageSrc:CGImageSource?
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
            if let url = URL.url(src, baseURL: baseURL) {
                if let urlLocal = self.delegate.map(url) {
                    imageSrc = CGImageSourceCreateWithURL(urlLocal as CFURL, nil)
                } else {
                    imageSrc = CGImageSourceCreateWithURL(url as CFURL, nil)
                }
                if imageSrc != nil && CGImageSourceGetCount(imageSrc!) > 0 {
                    imageRef = CGImageSourceCreateImageAtIndex(imageSrc!, 0, nil)
                }
            }
        }
        
        if let src = info["mask"] as? String {
            //maskSrc = SwipeParser.imageWith(src)
            if let url = URL.url(src, baseURL: baseURL),
                let urlLocal = self.delegate.map(url),
                let image = CGImageSourceCreateWithURL(urlLocal as CFURL, nil) {
                if CGImageSourceGetCount(image) > 0 {
                    maskSrc = CGImageSourceCreateImageAtIndex(image, 0, nil)
                }
            }
        }

        pathSrc = parsePath(info["path"], w: w0, h: h0, scale:scale)

        // The natural size is determined by the contents (either image or mask)
        var sizeContents:CGSize?
        if imageRef != nil {
            sizeContents = CGSize(width: CGFloat((imageRef?.width)!),
                                      height: CGFloat((imageRef?.height)!))
        } else if maskSrc != nil {
            sizeContents = CGSize(width: CGFloat((maskSrc?.width)!),
                                      height: CGFloat((maskSrc?.height)!))
        } else  if let path = pathSrc {
            let rc = path.boundingBoxOfPath
            sizeContents = CGSize(width: rc.origin.x + rc.width, height: rc.origin.y + rc.height)
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
        
        let w = w0 * scale.width
        let h = h0 * scale.height
        let frame:CGRect = {
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
            return CGRect(x: x, y: y, width: w, height: h)
        }()
        
        let view = InternalView(wrapper: self, frame: frame)
#if os(OSX)
        let layer = view.makeBackingLayer()
#else
        let layer = view.layer
#endif
        self.layer = layer
        
        if let values = info["anchor"] as? [Any], values.count == 2 && w0 > 0 && h0 > 0,
           let posx = SwipeParser.parsePercentAny(values[0], full: w0, defaultValue: 0),
           let posy = SwipeParser.parsePercentAny(values[1], full: h0, defaultValue: 0) {
            layer.anchorPoint = CGPoint(x: posx / w0, y: posy / h0)
        }
        
        if let values = info["pos"] as? [Any], values.count == 2,
           let posx = SwipeParser.parsePercentAny(values[0], full: dimension.width, defaultValue: 0),
           let posy = SwipeParser.parsePercentAny(values[1], full: dimension.height, defaultValue: 0) {
            layer.position = CGPoint(x: posx * scale.width, y: posy * scale.height)
        }
        
        if let value = info["action"] as? String {
            action = value
#if os(iOS) // tvOS has some focus issue with UIButton, figure out OSX later
            let btn = UIButton(type: UIButtonType.custom)
            btn.frame = view.bounds
            btn.addTarget(self, action: #selector(SwipeElement.buttonPressed), for: UIControlEvents.touchUpInside)
            btn.addTarget(self, action: #selector(SwipeElement.touchDown), for: UIControlEvents.touchDown)
            btn.addTarget(self, action: #selector(SwipeElement.touchUpOutside), for: UIControlEvents.touchUpOutside)
            view.addSubview(btn)
            self.btn = btn
#endif
            if action == "play" {
                notificationManager.addObserver(forName: .SwipePageDidStartPlaying, object: self.delegate, queue: OperationQueue.main) {
                    /*[unowned self]*/ (_: Notification!) -> Void in
                    // NOTE: Animation does not work because we are performing animation using the parent layer
                    //UIView.animateWithDuration(0.2, animations: { () -> Void in
                        layer.opacity = 0.0
                    //})
                }
                notificationManager.addObserver(forName: .SwipePageDidFinishPlaying, object: self.delegate, queue: OperationQueue.main) {
                    /*[unowned self]*/ (_: Notification!) -> Void in
                    // NOTE: Animation does not work because we are performing animation using the parent layer
                    //UIView.animateWithDuration(0.2, animations: { () -> Void in
                        layer.opacity = 1.0
                    //})
                }
            }
        } else if let eventsInfo = info["events"] as? [String:Any] {
            eventHandler.parse(eventsInfo)
        }

        if let enabled = info["enabled"] as? Bool {
            self.fEnabled = enabled
        }
        
        if let focusable = info["focusable"] as? Bool {
            self.fFocusable = focusable
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
            if let tiling = info["tiling"] as? Bool, tiling {
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
                var images = [CGImage]()
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
                    imageLayer.add(ani, forKey: "contents")
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
            if let values = self.info["slot"] as? [Int], values.count == 2 {
                slot = CGPoint(x: CGFloat(values[0]), y: CGFloat(values[1]))
            }
            if let url = URL.url(src, baseURL: baseURL),
                let urlLocal = self.delegate.map(url),
                let imageSource = CGImageSourceCreateWithURL(urlLocal as CFURL, nil), CGImageSourceGetCount(imageSource) > 0,
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
                contentsRect = CGRect(x: slot.x/self.slice.width, y: slot.y/self.slice.height, width: 1.0/self.slice.width, height: 1.0/self.slice.height)
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
            imageLayer.frame = CGRect(x: 0,y: 0,width: w,height: h)
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
            shapeLayer.frame = view.bounds
            shapeLayer.contentsScale = contentScale
            if let xpath = SwipeParser.transformedPath(path, param: info, size:frame.size) {
                shapeLayer.path = xpath
            } else {
                shapeLayer.path = path
            }
            shapeLayer.fillColor = SwipeParser.parseColor(info["fillColor"])
            shapeLayer.strokeColor = SwipeParser.parseColor(info["strokeColor"], defaultColor: blackColor)
            shapeLayer.lineWidth = SwipeParser.parseCGFloat(info["lineWidth"]) * self.scale.width
            
            SwipeElement.processShadow(info, scale:scale, layer: shapeLayer)

            shapeLayer.lineCap = "round"
            shapeLayer.strokeStart = SwipeParser.parseCGFloat(info["strokeStart"], defaultValue: 0.0)
            shapeLayer.strokeEnd = SwipeParser.parseCGFloat(info["strokeEnd"], defaultValue: 1.0)
            layer.addSublayer(shapeLayer)
            self.shapeLayer = shapeLayer
            if let tiling = info["tiling"] as? Bool, tiling {
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
            SwipeElement.processShadow(info, scale:scale, layer: layer)
        }
        
        var mds: Any? = info["markdown"]
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
        
        if let value = info["textArea"] as? [String:Any] {
            let textView = SwipeTextArea(parent: self, info: value, frame: view.bounds, screenDimension: self.screenDimension)
            helper = textView
            view.addSubview(helper!.view!)
        } else if let value = info["textField"] as? [String:Any] {
            let textView = SwipeTextField(parent: self, info: value, frame: view.bounds, screenDimension: self.screenDimension)
            helper = textView
            view.addSubview(helper!.view!)
        } else if let value = info["list"] as? [String:Any] {
            let list = SwipeList(parent: self, info: value, scale:self.scale, frame: view.bounds, screenDimension: self.screenDimension, delegate: self.delegate)
            helper = list
            view.addSubview(list.tableView)
            list.tableView.reloadData()
        }
        
        if let text = parseText(self, info: info, key:"text") {
            if self.helper == nil || !self.helper!.setText(text, scale:self.scale, info: info, dimension:screenDimension, layer: layer) {
                self.textLayer = SwipeElement.addTextLayer(text, scale:scale, info: info, dimension: screenDimension, layer: layer)
            }
        }
        
        // http://stackoverflow.com/questions/9290972/is-it-possible-to-make-avurlasset-work-without-a-file-extension
        var fStream:Bool = {
            if let fStream = info["stream"] as? Bool {
                return fStream
            }
            return false
        }()
        let urlVideoOrRadio:URL? = {
            if let src = info["video"] as? String,
                let url = URL.url(src, baseURL: baseURL) {
                return url
            }
            if let src = info["radio"] as? String,
                let url = URL.url(src, baseURL: baseURL) {
                fStream = true
                return url
            }
            return nil
        }()
        if let url = urlVideoOrRadio {
            let videoPlayer = AVPlayer()
            self.videoPlayer = videoPlayer
            self.hasObserver = false
            let videoLayer = XAVPlayerLayer(player: videoPlayer)
            videoLayer.frame = CGRect(x: 0.0, y: 0.0, width: w, height: h)
            if fScaleToFill {
                videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            }
            layer.addSublayer(videoLayer)

            let urlLocalOrStream:URL?
            if fStream {
                MyLog("SWElem stream=\(url)", level:2)
                urlLocalOrStream = url
            } else if let urlLocal = self.delegate.map(url) {
                urlLocalOrStream = urlLocal
            } else {
                urlLocalOrStream = nil
            }
            
            if let urlVideo = urlLocalOrStream {
                let playerItem = AVPlayerItem(url: urlVideo)
                videoPlayer.replaceCurrentItem(with: playerItem)
                if (videoStart > 0) {
                    MyLog("SWElem A seekTo \(videoStart)", level:0)
                }
                let timescale = videoPlayer.currentItem?.asset.duration.timescale ?? 600
                videoPlayer.seek(to: CMTime(seconds:Double(videoStart), preferredTimescale: timescale), toleranceBefore: tolerance, toleranceAfter: tolerance)

                notificationManager.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: OperationQueue.main) {
                    [unowned self] (_:Notification!) -> Void in
                    MyLog("SWElem play to end!", level: 1)
                    self.handleVideoEnd(videoPlayer: videoPlayer)
                }
            }
            
            notificationManager.addObserver(forName: .SwipePageShouldPauseAutoPlay, object: delegate, queue: OperationQueue.main) {
                [unowned self] (_:Notification!) -> Void in
                if self.fPlaying {
                    self.fPlaying = false
                    self.delegate.didFinishPlaying(self, completed:false)
                    videoPlayer.pause()
                }
            }
            notificationManager.addObserver(forName: .SwipePageShouldStartAutoPlay, object: delegate, queue: OperationQueue.main) {
                [unowned self] (_:Notification!) -> Void in
                if !self.fPlaying && layer.opacity > 0 {
                    self.fPlaying = true
                    self.delegate.didStartPlaying(self)
                    MyLog("SWElem videoPlayer.state = \(videoPlayer.status.rawValue)", level: 1)
                    if self.fNeedRewind {
                        MyLog("SWElem B seekTo \(self.videoStart)", level:0)
                        let timescale = videoPlayer.currentItem?.asset.duration.timescale ?? 600
                        videoPlayer.seek(to: CMTime(seconds:Double(self.videoStart), preferredTimescale: timescale), toleranceBefore: self.tolerance, toleranceAfter: self.tolerance)
                    }
                    videoPlayer.play()
                    self.fNeedRewind = false
                    
                    if let duration = self.videoDuration, !self.hasObserver {
                        // Async call to give the play time to seek (LATER: we may need to wait a bit)
                        self.hasObserver = true
                        DispatchQueue.main.async() {
                            MyLog("SWElem duration=\(duration) from \(self.videoStart) seeking=\(self.fSeeking)", level:0)
                            let time = CMTime(seconds: Double(self.videoStart + duration), preferredTimescale: 600)
                            videoPlayer.addBoundaryTimeObserver(forTimes: [time as NSValue], queue: nil) {
                                [weak self] in
                                MyLog("SWElem timeObserver pausing", level:0)
                                videoPlayer.pause()
                                self?.handleVideoEnd(videoPlayer: videoPlayer)
                            }
                        }
                    }
                }
            }
        }
        
        if let transform = SwipeParser.parseTransform(info, scaleX:scale.width, scaleY:scale.height, base: nil, fSkipTranslate: false, fSkipScale: self.shapeLayer != nil) {
            layer.transform = transform
        }
        
        layer.opacity = SwipeParser.parseFloat(info["opacity"])
        
        if let visible = info["visible"] as? Bool, !visible {
            layer.opacity = 0.0
        }
        
        if let to = info["to"] as? [String:Any] {
            let start, duration:Double
            if let timing = to["timing"] as? [Double],
                timing.count == 2 && timing[0] >= 0 && timing[0] <= timing[1] && timing[1] <= 1 {
                start = timing[0] == 0 ? 1e-10 : timing[0]
                duration = timing[1] - start
            } else {
                start = 1e-10
                duration = 1.0
            }
            var fSkipTranslate = false
            
            if let path = parsePath(to["pos"], w: w0, h: h0, scale:scale) {
                let pos = layer.position
                var xform = CGAffineTransform(translationX: pos.x, y: pos.y)
                let ani = CAKeyframeAnimation(keyPath: "position")
                ani.path = path.copy(using: &xform)
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
                layer.add(ani, forKey: "position")
                fSkipTranslate = true
            }

            if let transform = SwipeParser.parseTransform(to, scaleX:scale.width, scaleY:scale.height, base:info, fSkipTranslate: fSkipTranslate, fSkipScale: self.shapeLayer != nil) {
                let ani = CABasicAnimation(keyPath: "transform")
                ani.fromValue = NSValue(caTransform3D : layer.transform)
                ani.toValue = NSValue(caTransform3D : transform)
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.add(ani, forKey: "transform")
            }

            if let opacity = to["opacity"] as? Float {
                let ani = CABasicAnimation(keyPath: "opacity")
                ani.fromValue = layer.opacity
                ani.toValue = opacity
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.add(ani, forKey: "opacity")
            }
            
            if let backgroundColor = to["bc"] {
                let ani = CABasicAnimation(keyPath: "backgroundColor")
                ani.fromValue = layer.backgroundColor
                ani.toValue = SwipeParser.parseColor(backgroundColor)
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.add(ani, forKey: "backgroundColor")
            }
            if let borderColor = to["borderColor"] {
                let ani = CABasicAnimation(keyPath: "borderColor")
                ani.fromValue = layer.borderColor
                ani.toValue = SwipeParser.parseColor(borderColor)
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.add(ani, forKey: "borderColor")
            }
            if let borderWidth = to["borderWidth"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "borderWidth")
                ani.fromValue = layer.borderWidth
                ani.toValue = borderWidth * scale.width
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.add(ani, forKey: "borderWidth")
            }
            if let borderWidth = to["cornerRadius"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "cornerRadius")
                ani.fromValue = layer.cornerRadius
                ani.toValue = borderWidth * scale.width
                ani.fillMode = kCAFillModeBoth
                ani.beginTime = start
                ani.duration = duration
                layer.add(ani, forKey: "cornerRadius")
            }
            
            if let textLayer = self.textLayer {
                if let textColor = to["textColor"] {
                    let ani = CABasicAnimation(keyPath: "foregroundColor")
                    ani.fromValue = textLayer.foregroundColor
                    ani.toValue = SwipeParser.parseColor(textColor)
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    textLayer.add(ani, forKey: "foregroundColor")
                }
            }
            if let srcs = to["img"] as? [String] {
                var images = [CGImage]()
                for src in srcs {
                    if let url = URL.url(src, baseURL: baseURL),
                        let urlLocal = self.delegate.map(url),
                        let image = CGImageSourceCreateWithURL(urlLocal as CFURL, nil) {
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
                    imageLayer.add(ani, forKey: "contents")
                }
            }

            if let shapeLayer = self.shapeLayer {
                if let params = to["path"] as? [Any] {
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
                    shapeLayer.add(ani, forKey: "path")
                } else if let path = parsePath(to["path"], w: w0, h: h0, scale:scale) {
                    let ani = CABasicAnimation(keyPath: "path")
                    ani.fromValue = shapeLayer.path
                    ani.toValue = path
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "path")
                } else if let path = SwipeParser.transformedPath(pathSrc!, param: to, size:frame.size) {
                    let ani = CABasicAnimation(keyPath: "path")
                    ani.fromValue = shapeLayer.path
                    ani.toValue = path
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "path")
                }
                if let fillColor = to["fillColor"] {
                    let ani = CABasicAnimation(keyPath: "fillColor")
                    ani.fromValue = shapeLayer.fillColor
                    ani.toValue = SwipeParser.parseColor(fillColor)
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "fillColor")
                }
                if let strokeColor = to["strokeColor"] {
                    let ani = CABasicAnimation(keyPath: "strokeColor")
                    ani.fromValue = shapeLayer.strokeColor
                    ani.toValue = SwipeParser.parseColor(strokeColor)
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "strokeColor")
                }
                if let lineWidth = to["lineWidth"] as? CGFloat {
                    let ani = CABasicAnimation(keyPath: "lineWidth")
                    ani.fromValue = shapeLayer.lineWidth
                    ani.toValue = lineWidth * scale.width
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "lineWidth")
                }
                if let strokeStart = to["strokeStart"] as? CGFloat {
                    let ani = CABasicAnimation(keyPath: "strokeStart")
                    ani.fromValue = shapeLayer.strokeStart
                    ani.toValue = strokeStart
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "strokeStart")
                }
                if let strokeEnd = to["strokeEnd"] as? CGFloat {
                    let ani = CABasicAnimation(keyPath: "strokeEnd")
                    ani.fromValue = shapeLayer.strokeEnd
                    ani.toValue = strokeEnd
                    ani.beginTime = start
                    ani.duration = duration
                    ani.fillMode = kCAFillModeBoth
                    shapeLayer.add(ani, forKey: "strokeEnd")
                }
            }
        }
        
        if let fRepeat = info["repeat"] as? Bool, fRepeat {
            //NSLog("SE detected an element with repeat")
            self.fRepeat = fRepeat
            layer.speed = 0 // Independently animate it
        }
        
        if let animation = info["loop"] as? [String:Any],
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
            if let timing = animation["timing"] as? [Double],
                timing.count == 2 && timing[0] >= 0 && timing[0] <= timing[1] && timing[1] <= 1 {
                start = timing[0] == 0 ? 1e-10 : timing[0]
                duration = timing[1] - start
            } else {
                start = 1e-10
                duration = 1.0
            }
            let repeatCount = value(from: animation, key: "count", defaultValue: 1) as Float
        
            switch(style) {
            case "vibrate":
                let delta = value(from: animation, key: "delta", defaultValue: 10.0) as CGFloat
                let ani = CAKeyframeAnimation(keyPath: "transform")
                ani.values = [NSValue(caTransform3D:loopLayer.transform),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeTranslation(delta, 0.0, 0.0), loopLayer.transform)),
                              NSValue(caTransform3D:loopLayer.transform),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeTranslation(-delta, 0.0, 0.0), loopLayer.transform)),
                              NSValue(caTransform3D:loopLayer.transform)]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.add(ani, forKey: "transform")
            case "shift":
                let shiftLayer = (innerLayer == nil) ? layer : innerLayer!
                let ani = CAKeyframeAnimation(keyPath: "transform")
                let shift:CGSize = {
                    if let dir = animation["direction"] as? String {
                        switch(dir) {
                        case "n":
                            return CGSize(width: 0, height: -h)
                        case "e":
                            return CGSize(width: w, height: 0)
                        case "w":
                            return CGSize(width: -w, height: 0)
                        default:
                            return CGSize(width: 0, height: h)
                        }
                    } else {
                        return CGSize(width: 0, height: h)
                    }
                }()
                ani.values = [NSValue(caTransform3D:shiftLayer.transform),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeTranslation(shift.width, shift.height, 0.0), shiftLayer.transform))]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                shiftLayer.add(ani, forKey: "transform")
            case "blink":
                let ani = CAKeyframeAnimation(keyPath: "opacity")
                ani.values = [1.0, 0.0, 1.0]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.add(ani, forKey: "opacity")
            case "spin":
                let fClockwise = booleanValue(from: animation, key: "clockwise", defaultValue: true)
                let degree = (fClockwise ? 120 : -120) * CGFloat(M_PI / 180.0)
                let ani = CAKeyframeAnimation(keyPath: "transform")
                ani.values = [NSValue(caTransform3D:loopLayer.transform),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeRotation(degree, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeRotation(degree * 2, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeRotation(degree * 3, 0.0, 0.0, 1.0), loopLayer.transform))]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.add(ani, forKey: "transform")
            case "wiggle":
                let delta = value(from: animation, key: "delta", defaultValue: 15) * CGFloat(M_PI / 180.0)
                let ani = CAKeyframeAnimation(keyPath: "transform")
                ani.values = [NSValue(caTransform3D:loopLayer.transform),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeRotation(delta, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(caTransform3D:loopLayer.transform),
                              NSValue(caTransform3D:CATransform3DConcat(CATransform3DMakeRotation(-delta, 0.0, 0.0, 1.0), loopLayer.transform)),
                              NSValue(caTransform3D:loopLayer.transform)]
                ani.repeatCount = repeatCount
                ani.beginTime = start
                ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                ani.fillMode = kCAFillModeBoth
                loopLayer.add(ani, forKey: "transform")
            case "path":
                if let shapeLayer = self.shapeLayer {
                    var values = [shapeLayer.path!]
                    if let params = animation["path"] as? [Any] {
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
                        shapeLayer.add(ani, forKey: "path")
                    }
                }
            case "sprite":
                if let targetLayer = spriteLayer {
                    let ani = CAKeyframeAnimation(keyPath: "contentsRect")
                    let rc0 = CGRect(x: 0, y: slot.y/self.slice.height, width: 1.0/self.slice.width, height: 1.0/self.slice.height)
                    ani.values = Array(0..<Int(slice.width)).map() { (index:Int) -> NSValue in
                        NSValue(cgRect: CGRect(origin: CGPoint(x: CGFloat(index) / self.slice.width, y: rc0.origin.y), size: rc0.size))
                    }
                    ani.repeatCount = repeatCount
                    ani.beginTime = start
                    ani.duration = CFTimeInterval(duration / Double(ani.repeatCount))
                    ani.fillMode = kCAFillModeBoth
                    ani.calculationMode = kCAAnimationDiscrete
                    targetLayer.add(ani, forKey: "contentsRect")
                }
                //self.dir = (1,0)
                //self.repeatCount = CGFloat(repeatCount)
            default:
                break
            }
        }
        
        // Nested Elements
        if let elementsInfo = info["elements"] as? [[String:Any]] {
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scale, parent:self, delegate:self.delegate!)
                if let subview = element.loadViewInternal(CGSize(width: w0, height: h0), screenDimension: screenDimension) {
                    view.addSubview(subview)
                    children.append(element)
                }
            }
        }
        
        self.view = view
        setupGestureRecognizers()
        
        if let actions = eventHandler.actionsFor("load") {
            execute(self, actions: actions)
        }
        
        return view
    }

    // This function is called by SwipePage when unloading the view.
    // PARANOIA: Extra effort to clean up everything
    func clear() {
        notificationManager.clear()
    }
    
    private func parsePath(_ shape:Any?, w:CGFloat, h:CGFloat, scale:CGSize) -> CGPath? {
        var shape0: Any? = shape
        if let refs = shape as? [String:Any], let key = refs["ref"] as? String {
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
    
    func setTimeOffsetTo(_ offset:CGFloat, fAutoPlay:Bool = false, fElementRepeat:Bool = false) {
        if offset < 0.0 || offset > 1.0 {
            return
        }
        
        if let layer = self.layer, layer.speed == 0 {
            // independently animated
            layer.timeOffset = CFTimeInterval(offset)
        }
        
        for c in children {
            if let element = c as? SwipeElement {
                element.setTimeOffsetTo(offset, fAutoPlay: fAutoPlay, fElementRepeat: fElementRepeat)
            }
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
            let timeSec = videoStart + offset * (videoDuration ?? 1.0)
            let time = CMTimeMakeWithSeconds(Float64(timeSec), 600)
            if player.status == AVPlayerStatus.readyToPlay {
                self.fSeeking = true
                SwipeElement.objectCount -= 1 // to avoid false memory leak detection
                player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { (_:Bool) -> Void in
                    assert(Thread.current == Thread.main, "thread error")
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
    func handleVideoEnd(videoPlayer:AVPlayer) {
        if self.delegate != nil && self.delegate!.shouldRepeat(self) {
            MyLog("SWElem C seekTo \(self.videoStart)", level:0)
            let timescale = videoPlayer.currentItem?.asset.duration.timescale ?? 600
            videoPlayer.seek(to: CMTime(seconds:Double(videoStart), preferredTimescale: timescale), toleranceBefore: tolerance, toleranceAfter: tolerance)
            videoPlayer.play()
        } else {
            self.fNeedRewind = true
            if self.fPlaying {
                self.fPlaying = false
                self.delegate.didFinishPlaying(self, completed:true)
            }
        }
    }
    
    func isVideoElement() -> Bool {
        if self.videoPlayer != nil {
            return true
        }
        for c in children {
            if let element = c as? SwipeElement {
                if element.isVideoElement() {
                    return true
                }
            }
        }
        return false
    }
    
    func isRepeatElement() -> Bool {
        if fRepeat {
            return true
        }
        for c in children {
            if let element = c as? SwipeElement {
                if element.isRepeatElement() {
                    return true
                }
            }
        }
        return false
    }

    func parseText(_ originator: SwipeNode, info:[String:Any], key:String) -> String? {
        guard let value = info[key] else {
            return nil
        }
        if let text = value as? String {
            return text
        }
        guard let params = value as? [String:Any] else {
            return nil
        }
        if let valInfo = params["valueOf"] as? [String:Any] {
            if let text = originator.getValue(originator, info: valInfo) as? String {
                return text
            }
            return nil
        }
        else if let key = params["ref"] as? String,
               let text = delegate.localizedStringForKey(key) {
            return text
        }
        return SwipeParser.localizedString(params, langId: delegate.languageIdentifier())
    }

    static func processShadow(_ info:[String:Any], scale:CGSize, layer:CALayer) {
        if let shadowInfo = info["shadow"] as? [String:Any] {
            layer.shadowColor = SwipeParser.parseColor(shadowInfo["color"], defaultColor: UIColor.black.cgColor)
            layer.shadowOffset = SwipeParser.parseSize(shadowInfo["offset"], defaultValue: CGSize(width: 1, height: 1), scale:scale)
            layer.shadowOpacity = SwipeParser.parseFloat(shadowInfo["opacity"], defaultValue:0.5)
            layer.shadowRadius = SwipeParser.parseCGFloat(shadowInfo["radius"], defaultValue: 1.0) * scale.width
        }
    }
    
    static func processTextInfo(_ info:[String:Any], dimension:CGSize, scale:CGSize) -> ([String:Any], String, Bool, Bool, CTFont, CGFloat) {
        var fTextBottom = false
        var fTextTop = false
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = NSTextAlignment.center
        paragraphStyle.lineBreakMode = NSLineBreakMode.byWordWrapping
        var alignmentMode = kCAAlignmentCenter
        
        func processAlignment(_ alignment:String) {
            switch(alignment) {
            case "left":
                paragraphStyle.alignment = NSTextAlignment.left
                alignmentMode = kCAAlignmentLeft
            case "right":
                paragraphStyle.alignment = NSTextAlignment.right
                alignmentMode = kCAAlignmentRight
            case "justified":
                paragraphStyle.alignment = NSTextAlignment.justified
                alignmentMode = kCAAlignmentJustified
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
        func createFont() -> CTFont {
            for fontName in fontNames {
                return CTFontCreateWithName(fontName as CFString?, fontSize, nil)
            }
            return CTFontCreateWithName("Helvetica" as CFString?, fontSize, nil)
        }
        let font:CTFont = createFont()
        let attr:[String:Any] = [
            NSFontAttributeName:font,
            //NSForegroundColorAttributeName:UIColor(CGColor: SwipeParser.parseColor(info["textColor"], defaultColor: UIColor.blackColor().CGColor)),
            NSParagraphStyleAttributeName:paragraphStyle]
        return (attr, alignmentMode, fTextTop, fTextBottom, font, fontSize)
    }
    
    static func processTextStorage(_ text:String, attr:[String:Any], fTextBottom:Bool, fTextTop:Bool, rcBound:CGRect) -> CGRect {
        let textStorage = NSTextStorage(string: text, attributes: attr)
        let manager = NSLayoutManager()
        textStorage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: rcBound.width, height: 99999))
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        let box = manager.usedRect(for: container)
        var rcText = rcBound
        if fTextTop {
            rcText.origin.y = rcText.size.height - box.size.height
        } else if !fTextBottom {
            rcText.origin.y =  (rcText.size.height - box.size.height) / 2
        }
        return rcText
    }

    static func addTextLayer(_ text:String, scale:CGSize, info:[String:Any], dimension:CGSize, layer:CALayer) -> CATextLayer {
        let (attr, alignmentMode, fTextBottom, fTextTop, font, fontSize) = SwipeElement.processTextInfo(info, dimension: dimension, scale: scale)

        // NOTE: CATextLayer does not use the paragraph style in NSAttributedString (*).
        // In addition, we can't use NSAttributedString if we want to animate something,
        // such as foregroundColor and fontSize (**).
        let textLayer = CATextLayer()
#if !os(OSX)
        textLayer.contentsScale = UIScreen.main.scale
#endif
        textLayer.isWrapped = true // *
        textLayer.alignmentMode = alignmentMode // *
        textLayer.foregroundColor = SwipeParser.parseColor(info["textColor"], defaultColor: UIColor.black.cgColor) // animatable **
        textLayer.fontSize = fontSize // animatable **
        textLayer.font = font
        textLayer.string = text // NOTE: This is no longer an attributed string
        
        SwipeElement.processShadow(info, scale:scale, layer: layer)

        textLayer.frame = SwipeElement.processTextStorage(text, attr: attr, fTextBottom: fTextBottom, fTextTop: fTextTop, rcBound: layer.bounds)
        layer.addSublayer(textLayer)
        return textLayer
    }
    
    static func updateTextLayer(_ textLayer:CATextLayer, text:String, scale:CGSize, info:[String:Any], dimension:CGSize, layer:CALayer) {
        let (attr, alignmentMode, fTextBottom, fTextTop, font, fontSize) = SwipeElement.processTextInfo(info, dimension: dimension, scale: scale)
        
        textLayer.alignmentMode = alignmentMode // *
        textLayer.foregroundColor = SwipeParser.parseColor(info["textColor"], defaultColor: UIColor.black.cgColor) // animatable **
        textLayer.fontSize = fontSize // animatable **
        textLayer.font = font
        textLayer.string = text // NOTE: This is no longer an attributed string
        
        SwipeElement.processShadow(info, scale:scale, layer: layer)
        
        textLayer.frame = SwipeElement.processTextStorage(text, attr: attr, fTextBottom: fTextBottom, fTextTop: fTextTop, rcBound: layer.bounds)
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
    
    // SwipeView
    
    override func isFirstResponder() -> Bool {
        if let v = self.view {
            if v.isFirstResponder {
                return true
            }
            
            if helper != nil {
                return helper!.isFirstResponder()
            }
        }
        
        return super.isFirstResponder()
    }
    
    // SwipeNode
    
    override func getPropertyValue(_ originator: SwipeNode, property: String) -> Any? {
        if let val = helper?.getPropertyValue(originator, property: property) {
            return val
        }
        
        switch (property) {
        case "text":
            if let string = self.textLayer?.string as? String {
                return string
            } else {
                MyLog("SWElem textLayer.string is not a String!")
                return nil
            }
        case "text.length":
            if let string = self.textLayer?.string as? String {
                return string.characters.count
            } else {
                MyLog("SWElem textLayer.string is not a String!")
                return nil
            }
        case "enabled":
            return self.fEnabled
        case "focusable":
            return self.fFocusable
        default:
            return super.getPropertyValue(originator, property: property)
        }
    }
    
    override func getPropertiesValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
        if let val = self.helper?.getPropertiesValue(originator, info: info) {
            return val
        }

        let key = info.keys.first!
        
        if let val = info[key] as? String {
            return getPropertyValue(originator, property: val)
        } else {
            return nil
        }
    }
    
    override func getValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
        var name = "*"
        if let val = info["id"] as? String {
            name = val
        }
        
        var up = true
        if let val = info["search"] as? String {
            up = val != "children"
        }
        
        if (name == "*" || self.name.caseInsensitiveCompare(name) == .orderedSame) {
            if let attribute = info["property"] as? String {
                return getPropertyValue(originator, property: attribute)
            } else if let attributeInfo = info["property"] as? [String:Any] {
                return getPropertiesValue(originator, info: attributeInfo)
            }
        }

        var node: SwipeNode? = self
        
        if up {
            while node?.parent != nil {
                if let viewNode = node?.parent as? SwipeView {
                    for c in viewNode.children {
                        if let e = c as? SwipeElement {
                            if name == "*" || e.name.caseInsensitiveCompare(name) == .orderedSame {
                                if let attribute = info["property"] as? String {
                                    return e.getPropertyValue(originator, property: attribute)
                                } else if let attributeInfo = info["property"] as? [String:Any] {
                                    return e.getPropertiesValue(originator, info: attributeInfo)
                                }
                            }
                        }
                    }
                    
                    node = node?.parent
                } else {
                    return nil
                }
            }
        } else {
            for c in children {
                if let e = c as? SwipeElement {
                    return e.getValue(originator, info: info)
                }
            }
        }
        
        return nil
    }
    
    func setupAnimations(_ layer: CALayer, originator: SwipeNode, info: [String:Any]) {
        let dimension = self.screenDimension
        let baseURL = self.delegate.baseURL()
        var x = layer.frame.origin.x
        var y = layer.frame.origin.y
        var w0 = layer.frame.size.width
        var h0 = layer.frame.size.height
        
        let fScaleToFill = info["w"] as? String == "fill" || info["h"] as? String == "fill"
        if !fScaleToFill {
            if let value = info["w"] as? CGFloat {
                w0 = value
            } else if let value = info["w"] as? String {
                w0 = SwipeParser.parsePercent(value, full: dimension.width, defaultValue: dimension.width)
            } else if let valInfo = info["w"] as? [String:Any],
                let valOfInfo = valInfo["valueOf"] as? [String:Any],
                let value = originator.getValue(originator, info:valOfInfo) as? CGFloat {
                w0 = value
            }
            if let value = info["h"] as? CGFloat {
                h0 = value
            } else if let value = info["h"] as? String {
                h0 = SwipeParser.parsePercent(value, full: dimension.height, defaultValue: dimension.height)
            } else if let valInfo = info["h"] as? [String:Any],
                let valOfInfo = valInfo["valueOf"] as? [String:Any],
                let value = originator.getValue(originator, info:valOfInfo) as? CGFloat {
                h0 = value
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
        } else if let valInfo = info["x"] as? [String:Any],
            let valOfInfo = valInfo["valueOf"] as? [String:Any],
            let value = originator.getValue(originator, info:valOfInfo) as? CGFloat {
            x = value
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
        } else if let valInfo = info["y"] as? [String:Any],
            let valOfInfo = valInfo["valueOf"] as? [String:Any],
            let value = originator.getValue(originator, info:valOfInfo) as? CGFloat {
            y = value
        }
        //NSLog("SWEleme \(x),\(y),\(w0),\(h0),\(sizeContents),\(dimension),\(scale)")
        
        x *= self.scale.width
        y *= self.scale.height
        let w = w0 * self.scale.width
        let h = h0 * self.scale.height
        let frame = CGRect(x: x, y: y, width: w, height: h)
        layer.frame = frame
        
        let start, duration:Double
        if let timing = info["timing"] as? [Double],
            timing.count == 2 && timing[0] >= 0 && timing[0] <= timing[1] && timing[1] <= 1 {
            start = timing[0] == 0 ? 1e-10 : timing[0]
            duration = timing[1] - start
        } else {
            start = 1e-10
            duration = 1.0
        }
        
        if let durationSec = info["duration"] as? Double {
            CATransaction.setAnimationDuration(durationSec)
        }
        
        var fSkipTranslate = false
        
        if let path = self.parsePath(info["pos"], w: w0, h: h0, scale:self.scale) {
            let pos = layer.position
            var xform = CGAffineTransform(translationX: pos.x, y: pos.y)
            let ani = CAKeyframeAnimation(keyPath: "position")
            ani.path = path.copy(using: &xform)
            ani.beginTime = start
            ani.duration = duration
            ani.fillMode = kCAFillModeBoth
            ani.calculationMode = kCAAnimationPaced
            if let mode = info["mode"] as? String {
                switch(mode) {
                case "auto":
                    ani.rotationMode = kCAAnimationRotateAuto
                case "reverse":
                    ani.rotationMode = kCAAnimationRotateAutoReverse
                default: // or "none"
                    ani.rotationMode = nil
                }
            }
            layer.add(ani, forKey: "position")
            fSkipTranslate = true
        }
        
        if let transform = SwipeParser.parseTransform(info, scaleX:self.scale.width, scaleY:self.scale.height, base:info, fSkipTranslate: fSkipTranslate, fSkipScale: self.shapeLayer != nil) {
            let ani = CABasicAnimation(keyPath: "transform")
            ani.fromValue = NSValue(caTransform3D : layer.transform)
            ani.toValue = NSValue(caTransform3D : transform)
            ani.fillMode = kCAFillModeBoth
            ani.beginTime = start
            ani.duration = duration
            layer.add(ani, forKey: "transform")
        }
        
        if let opacity = info["opacity"] as? Float {
            let ani = CABasicAnimation(keyPath: "opacity")
            ani.fromValue = layer.opacity
            layer.opacity = opacity
            ani.toValue = layer.opacity
            //ani.fillMode = kCAFillModeBoth
            //ani.beginTime = start
            //ani.duration = duration
            layer.add(ani, forKey: "opacity")
        }
        
        if let backgroundColor = info["bc"] {
            let ani = CABasicAnimation(keyPath: "backgroundColor")
            ani.fromValue = layer.backgroundColor
            layer.backgroundColor = SwipeParser.parseColor(backgroundColor)
            ani.toValue = layer.backgroundColor
            //ani.fillMode = kCAFillModeBoth
            //ani.beginTime = start
            //ani.duration = duration
            layer.add(ani, forKey: "backgroundColor")
        }
        if let borderColor = info["borderColor"] {
            let ani = CABasicAnimation(keyPath: "borderColor")
            ani.fromValue = layer.borderColor
            layer.borderColor = SwipeParser.parseColor(borderColor)
            ani.toValue = layer.borderColor
            //ani.fillMode = kCAFillModeBoth
            //ani.beginTime = start
            //ani.duration = duration
            layer.add(ani, forKey: "borderColor")
        }
        if let borderWidth = info["borderWidth"] as? CGFloat {
            let ani = CABasicAnimation(keyPath: "borderWidth")
            ani.fromValue = layer.borderWidth
            ani.toValue = borderWidth * scale.width
            //ani.fillMode = kCAFillModeBoth
            //ani.beginTime = start
            //ani.duration = duration
            layer.add(ani, forKey: "borderWidth")
        }
        if let borderWidth = info["cornerRadius"] as? CGFloat {
            let ani = CABasicAnimation(keyPath: "cornerRadius")
            ani.fromValue = layer.cornerRadius
            ani.toValue = borderWidth * scale.width
            ani.fillMode = kCAFillModeBoth
            ani.beginTime = start
            ani.duration = duration
            layer.add(ani, forKey: "cornerRadius")
        }
        
        if let textLayer = self.textLayer {
            if let textColor = info["textColor"] {
                let ani = CABasicAnimation(keyPath: "foregroundColor")
                ani.fromValue = textLayer.foregroundColor
                textLayer.foregroundColor = SwipeParser.parseColor(textColor)
                ani.toValue = textLayer.foregroundColor
                //ani.beginTime = start
                //ani.duration = duration
                //ani.fillMode = kCAFillModeBoth
                textLayer.add(ani, forKey: "foregroundColor")
            }
        }
        
        if info["img"] != nil && self.imageLayer != nil {
            var urls = [URL:String]()
            var urlStr: String?
            
            if let str = info["img"] as? String {
                urlStr = str
            } else if let valInfo = info["img"] as? [String:Any],
                let valOfInfo = valInfo["valueOf"] as? [String:Any],
                let str = originator.getValue(originator, info:valOfInfo) as? String {
                urlStr = str
            }
            if urlStr != nil {
                if let url = URL.url(urlStr!, baseURL: baseURL) {
                    urls[url] = "img"
            
                    self.delegate.addedResourceURLs(urls) {
                        if let urlLocal = self.delegate.map(urls.first!.0),
                            let image = CGImageSourceCreateWithURL(urlLocal as CFURL, nil) {
                            if CGImageSourceGetCount(image) > 0 {
                                self.imageLayer!.contents = CGImageSourceCreateImageAtIndex(image, 0, nil)!
                            }
                        }
                    }
                }
            }
        }
        
        if let shapeLayer = self.shapeLayer {
            if let params = info["path"] as? [Any] {
                var values = [shapeLayer.path!]
                for param in params {
                    if let path = self.parsePath(param, w: w0, h: h0, scale:self.scale) {
                        values.append(path)
                    }
                }
                let ani = CAKeyframeAnimation(keyPath: "path")
                ani.values = values
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "path")
            } else if let path = self.parsePath(info["path"], w: w0, h: h0, scale:self.scale) {
                let ani = CABasicAnimation(keyPath: "path")
                ani.fromValue = shapeLayer.path
                ani.toValue = path
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "path")
            } /*else if let path = SwipeParser.transformedPath(pathSrc!, param: info, size:frame.size) {
                let ani = CABasicAnimation(keyPath: "path")
                ani.fromValue = shapeLayer.path
                ani.toValue = path
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.addAnimation(ani, forKey: "path")
            } */
            if let fillColor = info["fillColor"] {
                let ani = CABasicAnimation(keyPath: "fillColor")
                ani.fromValue = shapeLayer.fillColor
                ani.toValue = SwipeParser.parseColor(fillColor)
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "fillColor")
            }
            if let strokeColor = info["strokeColor"] {
                let ani = CABasicAnimation(keyPath: "strokeColor")
                ani.fromValue = shapeLayer.strokeColor
                ani.toValue = SwipeParser.parseColor(strokeColor)
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "strokeColor")
            }
            if let lineWidth = info["lineWidth"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "lineWidth")
                ani.fromValue = shapeLayer.lineWidth
                ani.toValue = lineWidth * self.scale.width
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "lineWidth")
            }
            if let strokeStart = info["strokeStart"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "strokeStart")
                ani.fromValue = shapeLayer.strokeStart
                ani.toValue = strokeStart
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "strokeStart")
            }
            if let strokeEnd = info["strokeEnd"] as? CGFloat {
                let ani = CABasicAnimation(keyPath: "strokeEnd")
                ani.fromValue = shapeLayer.strokeEnd
                ani.toValue = strokeEnd
                ani.beginTime = start
                ani.duration = duration
                ani.fillMode = kCAFillModeBoth
                shapeLayer.add(ani, forKey: "strokeEnd")
            }
        }
    }
            
    func update(_ originator: SwipeNode, info: [String:Any]) {
        for key in info.keys {
            if key != "events" {
                self.info[key] = info[key]
            }
        }
        
        DispatchQueue.main.async {
            self.layer?.removeAllAnimations()
            self.textLayer?.removeAllAnimations()
            
            UIView.animate(withDuration: 0.25, animations: {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setCompletionBlock({
                    if let eventsInfo = info["events"] as? [String:Any], self.delegate != nil {
                        let eventHandler = SwipeEventHandler()
                        eventHandler.parse(eventsInfo)
                        if let actions = eventHandler.actionsFor("completion") {
                            originator.execute(self, actions:actions)
                        }
                    }
                })
                
                if let text = self.parseText(originator, info: self.info, key:"text") {
                    if let textHelper = self.helper as? SwipeTextArea {
                        _ = textHelper.setText(text, scale: self.scale, info: self.info, dimension: self.screenDimension, layer: nil)
                    } else if let textHelper = self.helper as? SwipeTextField {
                        _ = textHelper.setText(text, scale: self.scale, info: self.info, dimension: self.screenDimension, layer: nil)
                    } else {
                        if self.textLayer == nil {
                            self.textLayer = SwipeElement.addTextLayer(text, scale: self.scale, info: self.info, dimension: self.screenDimension, layer: self.layer!)
                        } else {
                            SwipeElement.updateTextLayer(self.textLayer!, text: text, scale: self.scale, info: self.info, dimension: self.screenDimension, layer: self.layer!)
                        }
                    }
                }
                
                if let text = self.textLayer?.string as? String, self.info["textAlign"] != nil || self.info["textColor"] != nil || self.info["fontName"] != nil || self.info["fontSize"] != nil {
                    SwipeElement.updateTextLayer(self.textLayer!, text: text, scale: self.scale, info: self.info, dimension: self.screenDimension, layer: self.layer!)
                }
                
                self.setupAnimations(self.layer!, originator: originator, info: self.info)
                CATransaction.commit()
                
                }, completion: { (done: Bool) in
                    //print("uiview done: \(done)")
            })
            
            if let enabled = SwipeParser.parseAndEvalBool(originator, key: "enabled", info: self.info), self.fEnabled != enabled {
                self.fEnabled = enabled
                if enabled {
                    self.execute(self, actions: self.eventHandler.actionsFor("enabled"))
                } else {
                    self.execute(self, actions: self.eventHandler.actionsFor("disabled"))
                }
            }
            
            if let focusable = SwipeParser.parseAndEvalBool(originator, key: "focusable", info: self.info), self.fFocusable != focusable {
                self.fFocusable = focusable
                if focusable {
                    self.execute(self, actions: self.eventHandler.actionsFor("focusable"))
                } else {
                    self.execute(self, actions: self.eventHandler.actionsFor("unfocusable"))
                }
                self.view?.superview?.setNeedsFocusUpdate()
            }
        }
    }
    
    override func updateElement(_ originator: SwipeNode, name: String, up: Bool, info: [String:Any]) -> Bool {
        if let textHelper = self.helper as? SwipeTextArea {
            if textHelper.updateElement(originator, name: name, up: up, info: info) {
                return true
            }
        }
        if let textHelper = self.helper as? SwipeTextField {
            if textHelper.updateElement(originator, name: name, up: up, info: info) {
                return true
            }
        }
        
        if (name == "*" || self.name.caseInsensitiveCompare(name) == .orderedSame) {
            // Update self
            update(originator, info: info)
            return true
        }
        
        // Find named element in parent hierarchy and update
        var node: SwipeNode? = self
        
        if up {
            while node?.parent != nil {
                if let viewNode = node?.parent as? SwipeView {
                    for c in viewNode.children {
                        if let e = c as? SwipeElement {
                            if e.name.caseInsensitiveCompare(name) == .orderedSame {
                                e.update(originator, info: info)
                                return true
                            }
                        }
                    }
                    
                    node = node?.parent
                } else {
                    return false
                }
            }
        } else {
            for c in children {
                if let e = c as? SwipeElement {
                    if e.updateElement(originator, name:name, up:up, info:info) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    override func appendList(_ originator: SwipeNode, info: [String:Any]) {
        self.helper?.appendList(originator, info: info)
    }

    override func appendList(_ originator: SwipeNode, name: String, up: Bool, info: [String:Any])  -> Bool {
        if (name == "*" || self.name.caseInsensitiveCompare(name) == .orderedSame) {
            // Update self
            appendList(originator, info: info)
            return true
        }
        
        // Find named element in parent hierarchy and update
        var node: SwipeNode? = self
        
        if up {
            while node?.parent != nil {
                if let viewNode = node?.parent as? SwipeView {
                    for c in viewNode.children {
                        if let e = c as? SwipeElement {
                            if e.name.caseInsensitiveCompare(name) == .orderedSame {
                                e.appendList(originator, info: info)
                                return true
                            }
                        }
                    }
                    
                    node = node?.parent
                } else {
                    return false
                }
            }
        } else {
            for c in children {
                if let e = c as? SwipeElement {
                    if e.appendList(originator, name:name, up:up, info:info) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // SwipeViewDelegate
    func addedResourceURLs(_ urls:[URL:String], callback:@escaping () -> Void) {
        for (url,prefix) in urls {
            self.resourceURLs[url as URL] = prefix
        }
        self.delegate?.addedResourceURLs(urls) {
            callback()
        }
    }

}
