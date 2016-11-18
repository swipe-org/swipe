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

extension UIResponder {
    private weak static var _currentFirstResponder: UIResponder? = nil
    
    public class func currentFirstResponder() -> UIResponder? {
        UIResponder._currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(sender:)), to: nil, from: nil, for: nil)
        return UIResponder._currentFirstResponder
    }
    
    internal func findFirstResponder(sender: Any) {
        UIResponder._currentFirstResponder = self
    }
}

private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        print(text)
    }
}

protocol SwipePageDelegate: NSObjectProtocol {
    func dimension(_ page:SwipePage) -> CGSize
    func scale(_ page:SwipePage) -> CGSize
    func prototypeWith(_ name:String?) -> [String:Any]?
    func pageTemplateWith(_ name:String?) -> SwipePageTemplate?
    func pathWith(_ name:String?) -> Any?
#if !os(OSX) // REVIEW
    func speak(_ utterance:AVSpeechUtterance)
    func stopSpeaking()
#endif
    func currentPageIndex() -> Int
    func parseMarkdown(_ markdowns:[String]) -> NSAttributedString
    func baseURL() -> URL?
    func voice(_ k:String?) -> [String:Any]
    func languageIdentifier() -> String?
    func tapped()
}

extension Notification.Name {
    static let SwipePageDidStartPlaying = Notification.Name("SwipePageDidStartPlaying")
    static let SwipePageDidFinishPlaying = Notification.Name("SwipePageDidFinishPlaying")
    static let SwipePageShouldStartAutoPlay = Notification.Name("SwipePageShouldStartAutoPlay")
    static let SwipePageShouldPauseAutoPlay = Notification.Name("SwipePageShouldPauseAutoPlay")
}

class SwipePage: SwipeView, SwipeElementDelegate {
    // Debugging
    static var objectCount = 0
    var accessCount = 0
    var completionCount = 0

    // Public properties
    let index:Int
    var pageTemplate:SwipePageTemplate?
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
    private var fSeeking = false
    private var fEntered = false
    private var cPlaying = 0
    private var cDebug = 0
    private var fPausing = false
    private var offsetPaused:CGFloat?
    
    // Private lazy properties
    // Private properties allocated in loadView (we need to clean up in unloadView)
#if !os(OSX)
    private var utterance:AVSpeechUtterance?
#endif
    private var viewVideo:UIView? // Special layer to host auto-play video layers
    private var viewAnimation:UIView?
    private var aniLayer:CALayer?
    private var audioPlayer:AVAudioPlayer?
    
    init(index:Int, info:[String:Any], delegate:SwipePageDelegate) {
        self.index = index
        self.delegate = delegate
        self.pageTemplate = delegate.pageTemplateWith(info["template"] as? String)
        if self.pageTemplate == nil {
            self.pageTemplate = delegate.pageTemplateWith(info["scene"] as? String)
            if self.pageTemplate != nil {
                MyLog("SwPage DEPRECATED 'scene'; use 'template'")
            }
        }
        super.init(info: SwipeParser.inheritProperties(info, baseObject: pageTemplate?.pageTemplateInfo))
        SwipePage.objectCount += 1
    }

    func unloadView() {
#if !os(tvOS)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIKeyboardWillHide, object: nil)
#endif
        SwipeTimer.cancelAll()
        
        if let view = self.view {
            MyLog("SWPage  unloading @\(index)", level: 2)
            view.removeFromSuperview()
            for c in children {
                if let element = c as? SwipeElement {
                    element.clear() // PARANOIA (extra effort to clean up everything)
                }
            }
            children.removeAll()
            self.view = nil
            self.viewVideo = nil
            self.viewAnimation = nil
#if !os(OSX)
            self.utterance = nil
#endif
            self.audioPlayer = nil
        }
    }
    
    deinit {
        MyLog("SWPage  deinit \(index) \(accessCount) \(completionCount)", level: 1)
        if self.autoplay {
            NotificationCenter.default.post(name: .SwipePageShouldPauseAutoPlay, object: self)
        }
        SwipePage.objectCount -= 1
    }

    static func checkMemoryLeak() {
        //assert(SwipePage.objectCount == 0)
        if SwipePage.objectCount > 0 {
            NSLog("SWPage  memory leak detected ###")
        }
    }
    
    // Private lazy properties
    private lazy var backgroundColor:CGColor = {
        if let value = self.info["bc"] {
            return SwipeParser.parseColor(value)
        }
        return UIColor.white.cgColor
    }()

    private lazy var transition:String = {
        if let value = self.info["transition"] as? String {
            return value
        }
        return (self.animation == "scroll") ? "replace": "scroll" // default
    }()

    private lazy var fps:Int = {
        if let value = self.info["fps"] as? Int {
            return value
        }
        return 60 // default
    }()

    private lazy var animation:String = {
        if let value = self.info["play"] as? String {
            return value
        }
        if let value = self.info["animation"] as? String {
            NSLog("SWPage DEPRECATED 'animation'; use 'play'")
            return value
        }
        return "auto" // default
    }()

    private lazy var autoplay:Bool = {
        return self.animation == "auto" || self.animation == "always"
    }()

    private lazy var always:Bool = {
        return self.animation == "always"
    }()

    private lazy var scroll:Bool = {
        return self.animation == "scroll"
    }()

    private lazy var vibrate:Bool = {
        if let value = self.info["vibrate"] as? Bool {
            return value
        }
        return false
    }()

    private lazy var duration:CGFloat = {
        if let value = self.info["duration"] as? CGFloat {
            return value
        }
        return 0.2
    }()

    private lazy var fRepeat:Bool = {
        if let value = self.info["repeat"] as? Bool {
            return value
        }
        return false
    }()

    private lazy var rewind:Bool = {
        if let value = self.info["rewind"] as? Bool {
            return value
        }
        return false
    }()
    
    func setTimeOffsetWhileDragging(_ offset:CGFloat) {
        if self.scroll {
            fEntered = false // stops the element animation
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            assert(self.viewAnimation != nil, "must have self.viewAnimation")
            assert(self.viewVideo != nil, "must have viewVideo")
            self.aniLayer?.timeOffset = CFTimeInterval(offset)
            for c in children {
                if let element = c as? SwipeElement {
                    element.setTimeOffsetTo(offset)
                }
            }
            CATransaction.commit()
        }
    }
    
    func willLeave(_ fAdvancing:Bool) {
        MyLog("SWPage  willLeave @\(index) \(fAdvancing)", level: 2)
#if !os(OSX)
        if let _ = self.utterance {
            delegate.stopSpeaking()
            prepareUtterance() // recreate a new utterance to avoid reusing itt
        }
#endif
    }
    
    func pause(_ fForceRewind:Bool) {
        fPausing = true
        if let player = self.audioPlayer {
            player.stop()
        }
        
        NotificationCenter.default.post(name: .SwipePageShouldPauseAutoPlay, object: self)
        // auto rewind
        if self.rewind || fForceRewind {
            prepareToPlay()
        }
    }
    
    func didLeave(_ fGoingBack:Bool) {
        fEntered = false
        self.pause(fGoingBack)
        MyLog("SWPage  didLeave @\(index) \(fGoingBack)", level: 2)
    }
    
    func willEnter(_ fForward:Bool) {
        MyLog("SWPage  willEnter @\(index) \(fForward)", level: 2)
        if self.autoplay && fForward || self.always {
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

    func didEnter(_ fForward:Bool) {
        fEntered = true
        accessCount += 1
        if fForward && self.autoplay || self.always || self.fRepeat {
            autoPlay(false)
        } else if self.hasRepeatElement() {
            autoPlay(true)
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
    
    private func prepareToPlay(_ fForward:Bool = true) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.aniLayer?.timeOffset = fForward ? 0.0 : 1.0
        for c in children {
            if let element = c as? SwipeElement {
                element.setTimeOffsetTo(fForward ? 0.0 : 1.0)
            }
        }
        CATransaction.commit()
        self.offsetPaused = nil
    }
    
    func play() {
        // REVIEW: Remove this block once we detect the end of speech
        if let _ = self.utterance {
            delegate.stopSpeaking()
            prepareUtterance() // recreate a new utterance to avoid reusing it
        }
        
        self.autoPlay(false)
    }
    
    private func autoPlay(_ fElementRepeat:Bool) {
        fPausing = false
        if !fElementRepeat {
            playAudio()
            NotificationCenter.default.post(name: .SwipePageShouldStartAutoPlay, object: self)
        }
        assert(self.viewAnimation != nil, "must have self.viewAnimation")
        assert(self.viewVideo != nil, "must have viewVideo")
        if let offset = self.offsetPaused {
            timerTick(offset, fElementRepeat: fElementRepeat)
        } else {
            timerTick(0.0, fElementRepeat: fElementRepeat)
        }
        self.cDebug += 1
        self.cPlaying += 1
        self.didStartPlayingInternal()
    }
    
    private func timerTick(_ offset:CGFloat, fElementRepeat:Bool) {
        var fElementRepeatNext = fElementRepeat
        // NOTE: We don't want to add [unowned self] because the timer will fire anyway. 
        // During the shutdown sequence, the loop will stop when didLeave was called. 
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1000 * NSEC_PER_MSEC / UInt64(self.fps))) / Double(NSEC_PER_SEC), execute: {
            () -> Void in
            var offsetForNextTick:CGFloat?
            if self.fEntered && !self.fPausing {
                var nextOffset = offset + 1.0 / self.duration / CGFloat(self.fps)
                if nextOffset < 1.0 {
                    offsetForNextTick = nextOffset
                } else {
                    nextOffset = 1.0
                    if self.fRepeat {
                        self.playAudio()
                        offsetForNextTick = 0.0
                    } else if self.hasRepeatElement() {
                        offsetForNextTick = 0.0
                        fElementRepeatNext = true
                    }
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                if !fElementRepeatNext {
                    self.aniLayer?.timeOffset = CFTimeInterval(nextOffset)
                }
                for c in self.children {
                    if let element = c as? SwipeElement {
                        element.setTimeOffsetTo(nextOffset, fAutoPlay: true)
                    }
                }
                CATransaction.commit()
            }
            if let value = offsetForNextTick {
                self.timerTick(value, fElementRepeat: fElementRepeatNext)
            } else {
                self.offsetPaused = self.fPausing ? offset : nil
                self.cPlaying -= 1
                self.cDebug -= 1
                self.didFinishPlayingInternal()
            }
        })
    }
    
    // Returns the list of URLs of required resouces for this element (including children)
    lazy var resourceURLs:[URL:String] = {
        var urls = [URL:String]()
        let baseURL = self.delegate.baseURL()
        for key in ["audio"] {
            if let src = self.info[key] as? String,
                   let url = URL.url(src, baseURL: baseURL) {
                urls[url] = ""
            }
        }
        if let elementsInfo = self.info["elements"] as? [[String:Any]] {
            let scaleDummy = CGSize(width: 0.1, height: 0.1)
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scaleDummy, parent:self, delegate:self)
                for (url, prefix) in element.resourceURLs {
                    urls[url as URL] = prefix
                }
            }
        }
        if let pageTemplate = self.pageTemplate {
            for (url, prefix) in pageTemplate.resourceURLs {
                urls[url as URL] = prefix
            }
        }

        return urls
    }()
    
    lazy var prefetcher:SwipePrefetcher = {
        return SwipePrefetcher(urls:self.resourceURLs)
    }()

    func loadView(_ callback:((Void)->(Void))?) -> UIView {
    
        MyLog("SWPage  loading @\(index)", level: 2)
        assert(self.view == nil, "loadView self.view must be nil")
        let view = InternalView(wrapper: self, frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
        view.clipsToBounds = true
        self.view = view
        let viewVideo = UIView(frame: view.bounds)
        self.viewVideo = viewVideo
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

        let dimension = delegate.dimension(self)
        var transform = CATransform3DIdentity
        transform.m34 = -1 / dimension.width // default eyePosition is canvas width
        if let eyePosition = info["eyePosition"] as? CGFloat {
            transform.m34 = -1 / (dimension.width * eyePosition)
        }
        aniLayer.sublayerTransform = transform
        viewVideo.layer.sublayerTransform = transform

        view.addSubview(viewVideo)
        view.addSubview(viewAnimation)
        
        //view.tag = 100 + index // for debugging only
        layer.backgroundColor = self.backgroundColor
        if animation != "never" {
            aniLayer.speed = 0 // to manually specify the media timing
            aniLayer.beginTime = 0 // to manually specify the media timing
            aniLayer.fillMode = kCAFillModeForwards
        }
#if os(OSX)
        viewAnimation.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
#else
        viewVideo.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewAnimation.autoresizingMask = [.flexibleWidth, .flexibleHeight]
#endif
        //viewAnimation.backgroundColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.2)
        
        self.prefetcher.start { (completed:Bool, _:[URL], _:[NSError]) -> Void in
            if completed {
                if self.view != nil {
                    // NOTE: We are intentionally ignoring fetch errors (of network resources) here.
                    if let eventsInfo = self.info["events"] as? [String:Any] {
                        self.eventHandler.parse(eventsInfo)
                    }

                    self.loadSubviews()
                    callback?()
                }
            }
        }
        
        setupGestureRecognizers()
#if !os(tvOS)
        NotificationCenter.default.addObserver(self, selector: #selector(SwipePage.keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SwipePage.keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
#endif
        if let actions = eventHandler.actionsFor("load") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.execute(self, actions: actions)
            }
        }

        return view
    }
    
#if !os(tvOS)
    func keyboardWillShow(notification: Notification) {
        if let info = notification.userInfo {
            if let kbFrame = info[UIKeyboardFrameBeginUserInfoKey] as? CGRect {
                if let fr = findFirstResponder() {
                    let frFrame = fr.view!.frame
                    let myFrame = self.view!.frame
                    //let duration = info[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber as NSTimeInterval
                    //UIView.animateWithDuration(0.25, delay: 0.25, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
                        self.view!.frame = CGRect(x: 0, y: myFrame.origin.y - max(0, (frFrame.origin.y + frFrame.size.height) - (myFrame.size.height - kbFrame.size.height)), width: myFrame.size.height, height: myFrame.size.height)
                    //    }, completion: nil)
                }
            }
        }
    }
    
    func keyboardWillHide(notification: Notification) {
        if let _ = notification.userInfo {
            if findFirstResponder() != nil {
                let myFrame = self.view!.frame
                //let duration = info[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber as NSTimeInterval
                //UIView.animateWithDuration(0.25, delay: 0.25, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
                    self.view!.frame = CGRect(x: 0, y: 0, width: myFrame.size.height, height: myFrame.size.height)
                //    }, completion: nil)
            }
        }
    }
#endif
    
    private func loadSubviews() {
        let scale = delegate.scale(self)
        let dimension = delegate.dimension(self)
        if let value = self.info["audio"] as? String,
               let url = URL.url(value, baseURL: self.delegate.baseURL()),
               let urlLocal = self.prefetcher.map(url) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: urlLocal)
                audioPlayer?.prepareToPlay()
            } catch let error as NSError {
                NSLog("SWPage  audio error \(error)")
            }
        }

        prepareUtterance()

        if let elementsInfo = self.info["elements"] as? [[String:Any]] {
            for e in elementsInfo {
                let element = SwipeElement(info: e, scale:scale, parent:self, delegate:self)
                if let subview = element.loadView(dimension) {
                    if (self.autoplay || !self.scroll) && element.isVideoElement() {
                        // HACK: video element can not be played normally if it is added to the animation layer, which has the speed property zero.
                        self.viewVideo!.addSubview(subview)
                    } else {
                        self.viewAnimation!.addSubview(subview)
                    }
                    children.append(element)
                }
            } // for e in elementsInfo
        }
    }
    
    private func prepareUtterance() {
// REVIEW: Disabled for OSX for now
#if !os(OSX)
        if let speech = self.info["speech"] as? [String:Any],
           let text = parseText(self, info: speech, key: "text") {
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
                    //NSLog("SWPage lang=\(voice.language)")
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
    }
    
    // <SwipeElementDelegate> method
    
    func addedResourceURLs(_ urls:[URL:String], callback:@escaping () -> Void) {
        self.prefetcher.append(urls) { (completed:Bool, _:[URL], _:[NSError]) -> Void in
            if completed {
                callback()
            }
        }
    }
    
    func prototypeWith(_ name:String?) -> [String:Any]? {
        return delegate.prototypeWith(name)
    }
    
    // <SwipeElementDelegate> method
    func pathWith(_ name:String?) -> Any? {
        return delegate.pathWith(name)
    }

    // <SwipeElementDelegate> method
    func shouldRepeat(_ element:SwipeElement) -> Bool {
        return fEntered && self.fRepeat
    }
    
    // <SwipeElementDelegate> method
    func onAction(_ element:SwipeElement) {
        if let action = element.action {
            MyLog("SWPage  onAction \(action)", level: 2)
            if action == "play" {
                //prepareToPlay()
                //autoPlay()
                play()
            }
        }
    }
    
    // <SwipeElementDelegate> method
    func didStartPlaying(_ element:SwipeElement) {
        didStartPlayingInternal()
    }
    
    // <SwipeElementDelegate> method
    func didFinishPlaying(_ element:SwipeElement, completed:Bool) {
        if completed {
            completionCount += 1
        }
        didFinishPlayingInternal()
    }

    // <SwipeElementDelegate> method
    func baseURL() -> URL? {
        return delegate.baseURL()
    }
    
    // <SwipeElementDelegate> method
    func pageIndex() -> Int {
        return index
    }

    // <SwipeElementDelegate> method
    func localizedStringForKey(_ key:String) -> String? {
        if let strings = self.info["strings"] as? [String:Any],
               let texts = strings[key] as? [String:Any] {
            return SwipeParser.localizedString(texts, langId: delegate.languageIdentifier())
        }
        return nil
    }

    // <SwipeElementDelegate> method
    
    func languageIdentifier() -> String? {
        return delegate.languageIdentifier()
    }

    func parseText(_ originator: SwipeNode, info:[String:Any], key:String) -> String? {
        guard let value = info[key] else {
            return nil
        }
        if let text = value as? String {
            return text
        }
        if let ref = value as? [String:Any],
            let key = ref["ref"] as? String,
            let text = localizedStringForKey(key) {
            return text
        }
        return nil
    }
    
    private func didStartPlayingInternal() {
        cPlaying += 1
        if cPlaying==1 {
            //NSLog("SWPage  didStartPlaying @\(index)")
            NotificationCenter.default.post(name: .SwipePageDidStartPlaying, object: self)
        }
    }
    
    private func didFinishPlayingInternal() {
        assert(cPlaying > 0, "didFinishPlaying going negative! @\(index)")
        cPlaying -= 1
        if cPlaying == 0 {
            NotificationCenter.default.post(name: .SwipePageDidFinishPlaying, object: self)
        }
    }

#if !os(OSX)
    func speak(_ utterance:AVSpeechUtterance) {
        delegate.speak(utterance)
    }
#endif

    func parseMarkdown(_ element:SwipeElement, markdowns:[String]) -> NSAttributedString {
        return self.delegate.parseMarkdown(markdowns)
    }
    
    func map(_ url:URL) -> URL? {
        return self.prefetcher.map(url)
    }

    func isPlaying() -> Bool {
        let fPlaying = cPlaying > 0
        //assert(fPlaying == self.isPlayingOld())
        return fPlaying
    }
    
    /*
    private func isPlayingOld() -> Bool {
        for element in elements {
            if element.isPlaying() {
                return true
            }
        }
        return false
    }
    */
    func hasRepeatElement() -> Bool {
        for c in children {
            if let element = c as? SwipeElement {
                if element.isRepeatElement() {
                    return true
                }
            }
        }
        return false
    }
    
    
    // SwipeView
 
    override func tapped() {
        self.delegate.tapped()
    }
    
    
    // SwipeNode
    override func getValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
        var name = "*"
        if let val = info["id"] as? String {
            name = val
        }
        
        // first try own page property
        if (name == "*" || self.name.caseInsensitiveCompare(name) == .orderedSame) {
            if let attribute = info["property"] as? String {
                return getPropertyValue(originator, property: attribute)
            } else if let attributeInfo = info["property"] as? [String:Any] {
                return getPropertiesValue(originator, info: attributeInfo)
            }
        }
        
        for c in children {
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
        
        return nil
    }
    
    override func updateElement(_ originator: SwipeNode, name: String, up: Bool, info: [String:Any]) -> Bool {
        // Find named element and update
        for c in children {
            if let e = c as? SwipeElement {
                if e.name.caseInsensitiveCompare(name) == .orderedSame {
                    e.update(originator, info: info)
                    return true
                }
            }
        }
        
        return false
    }
    
    override func appendList(_ originator: SwipeNode, name: String, up: Bool, info: [String : Any]) -> Bool {
        // Find named element and update
        for c in children {
            if let e = c as? SwipeElement {
                if e.name.caseInsensitiveCompare(name) == .orderedSame {
                    e.appendList(originator, info: info)
                    return true
                }
            }
        }
        
        return false
    }

}
