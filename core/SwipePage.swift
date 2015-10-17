//
//  SwipePage.swift
//  Swipe
//
//  Created by satoshi on 6/3/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
import AVFoundation
#else
import UIKit
import AVFoundation
import MediaPlayer
#endif


private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

protocol SwipePageDelegate: NSObjectProtocol {
    func dimension(page:SwipePage) -> CGSize
    func scale(page:SwipePage) -> CGSize
    func prototypeWith(name:String?) -> [String:AnyObject]?
    func sceneWith(name:String?) -> SwipeScene?
    func pathWith(name:String?) -> AnyObject?
    func styleWith(name:String?) -> String?
#if !os(OSX) // REVIEW
    func speak(utterance:AVSpeechUtterance)
    func stopSpeaking()
#endif
    func currentPageIndex() -> Int
    func parseMarkdown(markdowns:[String]) -> NSAttributedString
    func baseURL() -> NSURL?
    func voice(k:String?) -> [String:AnyObject]
}

class SwipePage: NSObject, SwipeElementDelegate {
    // Debugging
    static var objectCount = 0

    static let didStartPlaying = "SwipePageDidStartPlaying"
    static let didFinishPlaying = "SwipePageDidFinishPlaying"
    static let shouldStartAutoPlay = "SwipePageShouldStartAutoPlay"
    static let shouldPauseAutoPlay = "SwipePageShouldPauseAutoPlay"

    // Public properties
    let index:Int
    var scene:SwipeScene?
    var view:UIView?
    weak var delegate:SwipePageDelegate!
    
    // Public Lazy Properties
    lazy var fixed:Bool = {
        let ret = (self.transition != "scroll")
        //NSLog("SWPage  fixed = \(self.transition) \(ret), \(self.index)")
        return self.transition != "scroll"
    }()
    lazy var replace:Bool = {
        return self.transition == "replace"
    }()

    // Private properties
    private var pageInfo:[String:AnyObject]
    private var elements = [SwipeElement]()
    private var fSeeking = false
    private var fEntered = false
    private var cPlaying = 0
    private var cDebug = 0
    
    // Private lazy properties
    // Private properties allocated in loadView (we need to clean up in unloadView)
#if !os(OSX)
    private var utterance:AVSpeechUtterance?
#endif
    private var viewAnimation:UIView?
    private var aniLayer:CALayer?
    private var audioPlayer:AVAudioPlayer?
    
    init(index:Int, pageInfo:[String:AnyObject], delegate:SwipePageDelegate) {
        self.index = index
        self.delegate = delegate
        self.scene = delegate.sceneWith(pageInfo["scene"] as? String)
        self.pageInfo = SwipeParser.inheritProperties(pageInfo, baseObject: scene?.sceneInfo)
        SwipePage.objectCount++
    }

    func unloadView() {
        if let view = self.view {
            MyLog("SWPage  unloading @\(index)", level: 2)
            view.removeFromSuperview()
            for element in elements {
                element.clear() // PARANOIA (extra effort to clean up everything)
            }
            elements.removeAll()
            self.view = nil
            self.viewAnimation = nil
#if !os(OSX)
            self.utterance = nil
#endif
            self.audioPlayer = nil
        }
    }
    
    deinit {
        MyLog("SWPage  deinit \(index)", level: 1)
        if self.autoplay {
            NSNotificationCenter.defaultCenter().postNotificationName(SwipePage.shouldPauseAutoPlay, object: self)
        }
        SwipePage.objectCount--
    }

    static func checkMemoryLeak() {
        assert(SwipePage.objectCount == 0)
    }
    
    // Private lazy properties
    private lazy var backgroundColor:CGColor = {
        if let value: AnyObject = self.pageInfo["bc"] {
            return SwipeParser.parseColor(value)
        }
        return UIColor.whiteColor().CGColor
    }()

    private lazy var transition:String = {
        if let value = self.pageInfo["transition"] as? String {
            return value
        }
        return (self.animation == "scroll") ? "replace": "scroll" // default
    }()

    private lazy var fps:Int = {
        if let value = self.pageInfo["fps"] as? Int {
            return value
        }
        return 60 // default
    }()

    private lazy var animation:String = {
        if let value = self.pageInfo["animation"] as? String {
            return value
        }
        return "auto" // default
    }()

    private lazy var autoplay:Bool = {
        return self.animation == "auto"
    }()

    private lazy var scroll:Bool = {
        return self.animation == "scroll"
    }()

    private lazy var vibrate:Bool = {
        if let value = self.pageInfo["vibrate"] as? Bool {
            return value
        }
        return false
    }()

    private lazy var duration:CGFloat = {
        if let value = self.pageInfo["duration"] as? CGFloat {
            return value
        }
        return 0.2
    }()

    private lazy var repeatCount:Bool = {
        if let value = self.pageInfo["repeat"] as? Bool {
            return value
        }
        return false
    }()

    private lazy var rewind:Bool = {
        if let value = self.pageInfo["rewind"] as? Bool {
            return value
        }
        return false
    }()
    
    func setTimeOffsetWhileDragging(offset:CGFloat) {
        if self.scroll {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            assert(self.viewAnimation != nil, "must have self.viewAnimation")
            self.aniLayer?.timeOffset = CFTimeInterval(offset)
            for element in elements {
                element.setTimeOffsetTo(offset)
            }
            CATransaction.commit()
        }
    }
    
    func willLeave(fAdvancing:Bool) {
#if !os(OSX)
        if let _ = self.utterance {
            delegate.stopSpeaking()
        }
#endif
    }
    
    func didLeave(fGoingBack:Bool) {
        fEntered = false
        if let player = audioPlayer {
            player.stop()
        }
        
        if self.autoplay {
            NSNotificationCenter.defaultCenter().postNotificationName(SwipePage.shouldPauseAutoPlay, object: self)
        }
        // auto rewind
        if self.rewind || fGoingBack {
            prepareToPlay()
        }
        MyLog("SWPage  didLeave @\(index) \(fGoingBack)", level: 2)
    }
    
    func willEnter(fForward:Bool) {
        MyLog("SWPage  willEnter @\(index) \(fForward)", level: 2)
        if self.autoplay && fForward {
            prepareToPlay()
        }
        if fForward && self.scroll {
            playAudio()
        }
    }
    
    private func playAudio() {
        if let player = audioPlayer {
            player.currentTime = 0.0
            player.play()
        }
#if !os(OSX)
        if let utterance = self.utterance {
            delegate.speak(utterance)
        }
        if self.vibrate {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
#endif
    }

    func didEnter(fForward:Bool) {
        fEntered = true
        if fForward && self.autoplay {
            autoPlay()
        }
        MyLog("SWPage  didEnter @\(index) \(fForward)", level: 2)
    }
    
    func prepare() {
        if scroll {
            prepareToPlay(index > self.delegate.currentPageIndex())
        } else {
            if index < self.delegate.currentPageIndex() {
                prepareToPlay(rewind)
            }
        }
    }
    
    private func prepareToPlay(fForward:Bool = true) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.aniLayer?.timeOffset = fForward ? 0.0 : 1.0
        for element in elements {
            element.setTimeOffsetTo(fForward ? 0.0 : 1.0)
        }
        CATransaction.commit()
    }
    
    private func autoPlay() {
        playAudio()
        NSNotificationCenter.defaultCenter().postNotificationName(SwipePage.shouldStartAutoPlay, object: self)
        /*
        for element in elements {
            element.autoplay()
        }
        */
        //NSLog("SWPage  autoPlay @\(index) with \(cPlaying)")
        assert(self.viewAnimation != nil, "must have self.viewAnimation")
        timerTick(0.0)
        cDebug++
        self.didStartPlayingInternal()
    }
    
    private func timerTick(offset:CGFloat) {
        // NOTE: We don't want to add [unowned self] because the timer will fire anyway. 
        // During the shutdown sequence, the loop will stop when didLeave was called. 
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1000 * NSEC_PER_MSEC / UInt64(self.fps))), dispatch_get_main_queue(), {
            () -> Void in
            var offsetForNextTick:CGFloat?
            if self.fEntered {
                var nextOffset = offset + 1.0 / self.duration / CGFloat(self.fps)
                if nextOffset < 1.0 {
                    offsetForNextTick = nextOffset
                } else {
                    nextOffset = 1.0
                    if self.repeatCount {
                        self.playAudio()
                        offsetForNextTick = 0.0
                    }
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.aniLayer?.timeOffset = CFTimeInterval(nextOffset)
                for element in self.elements {
                    element.setTimeOffsetTo(nextOffset, fAutoPlay: true)
                }
                CATransaction.commit()
            }
            if let value = offsetForNextTick {
                self.timerTick(value)
            } else {
                self.cDebug--
                self.didFinishPlayingInternal()
            }
        })
    }
    
    // Returns the list of URLs of required resouces for this element (including children)
    private lazy var resourceURLs:[NSURL:String] = {
        var urls = [NSURL:String]()
        let baseURL = self.delegate.baseURL()
        for key in ["audio"] {
            if let src = self.pageInfo[key] as? String,
                   url = NSURL.url(src, baseURL: baseURL) {
                urls[url] = ""
            }
        }
        if let elementsInfo = self.pageInfo["elements"] as? [[String:AnyObject]] {
            let scaleDummy = CGSizeMake(0.1, 0.1)
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scaleDummy, delegate:self)
                for (url, prefix) in element.resourceURLs {
                    urls[url] = prefix
                }
            }
        }
        if let scene = self.scene {
            for (url, prefix) in scene.resourceURLs {
                urls[url] = prefix
            }
        }

        return urls
    }()
    
    private lazy var prefetcher:SwipePrefetcher = {
        return SwipePrefetcher(urls:self.resourceURLs)
    }()

    func loadView() -> UIView {
    
        MyLog("SWPage  loading @\(index)", level: 2)
        assert(self.view == nil, "loadView self.view must be nil")
        let view = UIView(frame: CGRectMake(0.0, 0.0, 100.0, 100.0))
        self.view = view
        let viewAnimation = UIView(frame: view.bounds)
        self.viewAnimation = viewAnimation
#if os(OSX)
        let layer = view.makeBackingLayer()
        let aniLayer = viewAnimation.makeBackingLayer()
#else
        let layer = view.layer
        let aniLayer = viewAnimation.layer
#endif
        self.aniLayer = aniLayer
        view.addSubview(viewAnimation)
        
        //view.tag = 100 + index // for debugging only
        layer.backgroundColor = self.backgroundColor
        aniLayer.speed = 0 // to manually specify the media timing
        aniLayer.beginTime = 0 // to manually specify the media timing
        aniLayer.fillMode = kCAFillModeForwards
#if os(OSX)
        viewAnimation.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
#else
        viewAnimation.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
#endif
        //viewAnimation.backgroundColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.2)
        
        self.prefetcher.start { (_:[NSURL], _:[NSError]) -> Void in
            if self.view != nil {
                // NOTE: We are intentionally ignoring fetch errors (of network resources) here.
                self.loadSubviews()
            }
        }
        return view
    }
    
    private func loadSubviews() {
        let scale = delegate.scale(self)
        let dimension = delegate.dimension(self)
        if let value = self.pageInfo["audio"] as? String,
               url = NSURL.url(value, baseURL: self.delegate.baseURL()),
               urlLocal = self.prefetcher.map(url) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOfURL: urlLocal)
                audioPlayer?.prepareToPlay()
            } catch let error as NSError {
                NSLog("SWPage  audio error \(error)")
            }
        }

// REVIEW: Disabled for OSX for now
#if !os(OSX)
        if let speech = self.pageInfo["speech"] as? [NSObject:AnyObject],
           let text = speech["text"] as? String {
            let voice = self.delegate.voice(speech["voice"] as? String)
            let utterance = AVSpeechUtterance(string: text)
            
            // BCP-47 code
            if let lang = voice["lang"] as? String {
                // HACK: Work-around an iOS9 bug
                // http://stackoverflow.com/questions/30794082/how-do-we-solve-an-axspeechassetdownloader-error-on-ios
                // https://forums.developer.apple.com/thread/19079?q=AVSpeechSynthesisVoice
                let voices = AVSpeechSynthesisVoice.speechVoices()
                var theVoice:AVSpeechSynthesisVoice?
                for voice in voices {
                    if lang == voice.language {
                        theVoice = voice
                        break;
                    }
                }
                if let voice = theVoice {
                    utterance.voice = voice
                } else {
                    NSLog("SWPage  Voice for \(lang) is not available (iOS9 bug)")
                }
                // utterance.voice = AVSpeechSynthesisVoice(language: lang)
            }
            
            if let pitch = voice["pitch"] as? Float {
                if pitch >= 0.5 && pitch < 2.0 {
                    utterance.pitchMultiplier = pitch
                }
            }
            if let rate = voice["rate"] as? Float {
                if rate >= 0.0 && rate <= 1.0 {
                    utterance.rate = AVSpeechUtteranceMinimumSpeechRate + (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * rate
                } else if rate > 1.0 && rate <= 2.0 {
                    utterance.rate = AVSpeechUtteranceDefaultSpeechRate + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate) * (rate - 1.0)
                }
            }
            self.utterance = utterance
        }
#endif

        if let elementsInfo = self.pageInfo["elements"] as? [[String:AnyObject]] {
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scale, delegate:self)
                if let subview = element.loadView(dimension) {
                    if self.autoplay && element.isVideoElement() {
#if os(OSX)
                        self.view!.addSubview(subview, positioned: NSWindowOrderingMode.Below, relativeTo: self.viewAnimation)
#else
                        self.view!.insertSubview(subview, belowSubview: self.viewAnimation!)
#endif
                    } else {
                        self.viewAnimation!.addSubview(subview)
                    }
                    elements.append(element)
                }
            } // for e in elementsInfo
        }
    }
    
    // <SwipeElementDelegate> method
    func prototypeWith(name:String?) -> [String:AnyObject]? {
        return delegate.prototypeWith(name)
    }
    
    // <SwipeElementDelegate> method
    func pathWith(name:String?) -> AnyObject? {
        return delegate.pathWith(name)
    }

    // <SwipeElementDelegate> method
    func styleWith(name:String?) -> String? {
        return delegate.styleWith(name)
    }

    // <SwipeElementDelegate> method
    func shouldRepeat(element:SwipeElement) -> Bool {
        return fEntered && self.repeatCount
    }
    
    // <SwipeElementDelegate> method
    func onAction(element:SwipeElement) {
        if let action = element.action {
            MyLog("SWPage  onAction \(action)", level: 2)
            if action == "play" {
                prepareToPlay()
                autoPlay()
            }
        }
    }
    
    // <SwipeElementDelegate> method
    func didStartPlaying(element:SwipeElement) {
        didStartPlayingInternal()
    }
    
    // <SwipeElementDelegate> method
    func didFinishPlaying(element:SwipeElement) {
        didFinishPlayingInternal()
    }

    // <SwipeElementDelegate> method
    func baseURL() -> NSURL? {
        return delegate.baseURL()
    }
    
    // <SwipeElementDelegate> method
    func pageIndex() -> Int {
        return index
    }
    
    private func didStartPlayingInternal() {
        cPlaying++
        if cPlaying==1 {
            //NSLog("SWPage  didStartPlaying @\(index)")
            NSNotificationCenter.defaultCenter().postNotificationName(SwipePage.didStartPlaying, object: self)
        }
    }
    
    private func didFinishPlayingInternal() {
        assert(cPlaying > 0, "didFinishPlaying going negative! @\(index)")
        cPlaying--
        if cPlaying == 0 {
            NSNotificationCenter.defaultCenter().postNotificationName(SwipePage.didFinishPlaying, object: self)
        }
    }

#if !os(OSX)
    func speak(utterance:AVSpeechUtterance) {
        delegate.speak(utterance)
    }
#endif

    func parseMarkdown(element:SwipeElement, markdowns:[String]) -> NSAttributedString {
        return self.delegate.parseMarkdown(markdowns)
    }
    
    func map(url:NSURL) -> NSURL? {
        return self.prefetcher.map(url)
    }
}
