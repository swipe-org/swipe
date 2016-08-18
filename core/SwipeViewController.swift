//
//  SwipeViewController.swift
//  Swipe
//
//  Created by satoshi on 6/3/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
public typealias UIViewController = NSViewController
public typealias UIScrollView = NSScrollView
#else
import UIKit
#endif

import AVFoundation

private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipeViewController: UIViewController, UIScrollViewDelegate, SwipeDocumentViewer, SwipeBookDelegate {
    var book:SwipeBook!
    weak var delegate:SwipeDocumentViewerDelegate?
    private var fAdvancing = true
    private let notificationManager = SNNotificationManager()
#if os(tvOS)
    // scrollingTarget has an index to the target page during the scrolling animation
    // as the result of swiping
    private var scrollingTarget:Int?
    private var scrollingCount = 0 // number of pending animations
#endif

    lazy var scrollView:UIScrollView = {
        let scrollView = UIScrollView()
#if os(iOS)
        scrollView.pagingEnabled = true // paging is not available for tvOS
#endif
        scrollView.delegate = self
        return scrollView
    }()

    //
    // Computed Properties (private)
    //
    private var scrollPos:CGFloat {
        return pagePosition(self.scrollView.contentOffset)
    }
    
    private var scrollIndex:Int {
        return Int(self.scrollPos + 0.5)
    }
    
    private func pagePosition(offset:CGPoint) -> CGFloat {
        let size = self.scrollView.frame.size
        return self.book.horizontal ? offset.x / size.width : offset.y / size.height
    }
    
    deinit {
#if os(tvOS)
        MyLog("SWView deinit c=\(scrollingCount)", level:1)
#endif
        // Even though book is unwrapped, there is a rare case that book is nil 
        // (during the construction).
        if self.book != nil && self.book.pages.count > 0 {
            self.book.currenPage.willLeave(false)
            self.book.currenPage.didLeave(false)
            // PARANOIA
            for i in -2...2 {
                removeViewAtIndex(self.book.pageIndex - i)
            }
        }
    }

    // <SwipeDocumentViewerDelegate> method
    func tapped() {
        self.delegate?.tapped()
    }
    
    // <SwipeDocumentViewer> method
    func documentTitle() -> String? {
        return self.book.title
    }

    // <SwipeDocumentViewer> method
    func loadDocument(document:[String:AnyObject], size:CGSize, url:NSURL?, state:[String:AnyObject]?, callback:(Float, NSError?)->(Void)) throws {
        self.book = SwipeBook(bookInfo: document, url: url, delegate: self)

        if let languages = self.book.languages(),
               language = languages.first,
               langId = language["id"] as? String {
            self.book.langId = langId
        }

        if book.viewstate {
            if let pageIndex = state?["page"] as? Int where pageIndex < self.book.pages.count {
                self.book.pageIndex = pageIndex
            }
            if let langId = state?["langId"] as? String {
                self.book.langId = langId
            }
        }
        
        var urlsAll = [NSURL:String]()
        for page in self.book.pages {
            let urls = page.resourceURLs
            for (url, prefix) in urls {
                urlsAll[url] = prefix
            }
        }
        //NSLog("SVC urlsAll = \(urlsAll)")
        let prefetcher = SwipePrefetcher(urls: urlsAll)
        prefetcher.start { (completed:Bool, _:[NSURL], _:[NSError]) -> Void in
            callback(prefetcher.progress, nil)
        }
    }

    // <SwipeDocumentViewer> method
    func setDelegate(delegate:SwipeDocumentViewerDelegate) {
        self.delegate = delegate
    }

    // <SwipeDocumentViewer> method
    func hideUI() -> Bool {
        return true
    }

    // <SwipeDocumentViewer> method
    func landscape() -> Bool {
        return self.book.landscape
    }
    
    // <SwipeDocumentViewer> method
    func becomeZombie() {
        notificationManager.clear()
    }

    // <SwipeDocumentViewer> method
    func saveState() -> [String:AnyObject]? {
        return ["page":self.book.pageIndex, "langId":self.book.langId]
    }

    // <SwipeDocumentViewer> method
    func languages() -> [[String:AnyObject]]? {
        return self.book.languages()
    }
    
    // <SwipeDocumentViewer> method
    func reloadWithLanguageId(langId:String) {
        self.book.langId = langId
        self.adjustIndex(self.book.pageIndex, fForced: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.scrollView)
        
        self.view.layer.backgroundColor = book.backgroundColor
#if os(tvOS)
        // Since the paging is not enabled on tvOS, we handle PanGesture directly at this view instead.
        // scrollView.panGestureRecognizer.allowedTouchTypes = [UITouchType.Indirect.rawValue, UITouchType.Direct.rawValue]
        //scrollView.panGestureRecognizer.enabled = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SwipeViewController.handlePan(_:)))
        self.view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(SwipeViewController.handlePlayButton(_:)))
        tap.allowedPressTypes = [UIPressType.PlayPause.rawValue]
        self.view.addGestureRecognizer(tap)
#endif
    
        notificationManager.addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
            [unowned self] (_:NSNotification!) -> Void in
            MyLog("SWView DidBecomeActive")
            // iOS & tvOS removes all the animations associated with CALayers when the app becomes the background mode. 
            // Therefore, we need to recreate all the pages. 
            //
            // Without this delay, the manual animation won't work after putting the app in the background once.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(300 * NSEC_PER_MSEC)), dispatch_get_main_queue()) {
                self.adjustIndex(self.book.pageIndex, fForced: true)
            }
        }
    }

#if os(tvOS)
    // No need to give the focus to the scrollView becfause we handle the PanGesture at this view level.
    //override weak var preferredFocusedView: UIView? { return self.scrollView }
#endif

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        //
        // This is the best place to know the actual view size. See the following Q&A in stackoverflow.
        // http://stackoverflow.com/questions/6757018/why-am-i-having-to-manually-set-my-views-frame-in-viewdidload
        //
        //
        var frame = self.view.bounds
        let ratioView = frame.size.height / frame.size.width
        let dimension = book.dimension
        let ratioBook = dimension.height / dimension.width
        if ratioBook > ratioView {
            frame.size.width = frame.size.height / ratioBook
            frame.origin.x = (self.view.bounds.size.width - frame.size.width) / 2
        } else {
            frame.size.height = frame.size.width * ratioBook
            frame.origin.y = (self.view.bounds.size.height - frame.size.height) / 2
        }
        scrollView.frame = frame
        
        var size = frame.size
        book.viewSize = size
        if book.horizontal {
            size.width *= CGFloat(book.pages.count)
        } else {
            size.height *= CGFloat(book.pages.count)
        }
        
        if scrollView.contentSize != size {
            scrollView.contentSize = size
            adjustIndex(self.book.pageIndex, fForced: true, fDeferredEnter: true)
            let offset = self.book.horizontal ? CGPointMake((CGFloat(self.book.pageIndex)) * frame.size.width, 0) : CGPointMake(0, (CGFloat(self.book.pageIndex)) * frame.size.height)
            self.scrollView.contentOffset = offset
        }
    }
    
/*
    override func shouldAutorotate() -> Bool {
        return false
    }
*/
    
    // Debugging only
    func tagsString() -> String {
        let tags = scrollView.subviews.map({ (e:AnyObject) -> String in
            let subview = e as! UIView
            return "\(subview.tag)"
        })
        return "\(tags)"
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let pos = self.scrollPos
        let index = Int(pos)
        if index >= 0 {
            let pagePrev = self.book.pages[index]
            if pagePrev.fixed {
                if let viewPrev = pagePrev.view {
                    var rc = viewPrev.frame
                    rc.origin = self.scrollView.contentOffset
                    viewPrev.frame = rc
                }
            }
        }
        if index+1 < self.book.pages.count {
            let pageNext = self.book.pages[index + 1]
            if let viewNext = pageNext.view {
                let offset = pos - CGFloat(index)
                pageNext.setTimeOffsetWhileDragging(offset)
                if pageNext.fixed {
                    if offset > 0.0 && pageNext.replace {
                        viewNext.alpha = 1.0
                    } else {
                        viewNext.alpha = offset
                    }
                    var rc = viewNext.frame
                    rc.origin = self.scrollView.contentOffset
                    viewNext.frame = rc
                }
            }
        }
        if index+2 < self.book.pages.count {
            let pageNext2 = self.book.pages[index + 2]
            if pageNext2.fixed {
                if let viewNext2 = pageNext2.view {
                    viewNext2.alpha = 0.0
                }
            }
        }
    }

#if os(iOS)
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        let _:CGFloat, index:Int = self.scrollIndex
        //MyLog("SwipeVCWillBeginDragging, \(self.book.pageIndex) to \(index)")
        if self.adjustIndex(index) {
            MyLog("SWView detected continuous scrolling to @\(self.book.pageIndex)")
        }
    }
    
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let pt = targetContentOffset.memory
        let target = Int(pagePosition(pt) + 0.5)
        if target != self.book.pageIndex {
            // Forward paging was just initiated by the user's dragging
            //MyLog("SWView willEndDragging \(self.book.pageIndex) \(target)")
            self.book.currenPage.willLeave(fAdvancing)
            
            let page = self.book.pages[target]
            fAdvancing = target > self.book.pageIndex
            page.willEnter(fAdvancing)
        } else {
            let page = self.book.currenPage
            let size = self.scrollView.frame.size
            if !page.isPlaying() && (self.book.horizontal && scrollView.contentOffset.x < -size.width/8.0
              || !self.book.horizontal && scrollView.contentOffset.y < -size.height/8.0) {
                MyLog("SWView  EndDragging underscrolling detected \(scrollView.contentOffset)", level:1)
                page.willLeave(false)
                page.willEnter(true)
                page.didEnter(true)
            }
        }
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        let index = self.scrollIndex
        
        if !self.adjustIndex(index) {
            MyLog("SWView didEndDecelerating same", level: 1)
        }
        self.fAdvancing = false
    }
    
#elseif os(tvOS)
    func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        let index = self.scrollIndex
        self.scrollingCount -= 1
        MyLog("SWView didEndScrolling \(index), \(scrollingTarget), c=\(scrollingCount)", level: 1)
        if self.scrollingCount > 0 {
            return
        }
        self.scrollingTarget = nil
/*
        if let target = scrollingTarget {
            if target == index {
                MyLog("SWView didEndScrolling processing \(index), \(scrollingTarget)", level: 1)
                scrollingTarget = nil
            } else {
                MyLog("SWView didEndScrolling ignoring \(index), \(scrollingTarget) ###", level: 1)
                return
            }
        } else {
            MyLog("SWView didEndScrolling no scrollingTarget \(index) ???", level: 1)
        }
*/
        
        if !self.adjustIndex(index) {
            MyLog("SWView didEndScrolling same", level: 1)
        }
        self.fAdvancing = false
    }
    
    func handlePlayButton(recognizer:UITapGestureRecognizer) {
        let page = self.book.currenPage
        let fPlaying = page.isPlaying()
        MyLog("SWView  handlePlayButton \(fPlaying)", level: 1)
        if fPlaying {
            page.pause(false)
        } else {
            page.play()
        }
        /*
        page.willLeave(false)
        page.didLeave(false)
        page.willEnter(!fPlaying)
        page.didEnter(!fPlaying)
        */
    }

    func handlePan(recognizer:UIPanGestureRecognizer) {
        let translation = recognizer.translationInView(self.view)
        let velocity = recognizer.velocityInView(self.view)
        let size = self.scrollView.frame.size
        var ratio = self.book.horizontal ? -translation.x / size.width : -translation.y / size.height
        ratio = min(max(ratio, -0.99), 0.99)
        
        if let target = self.scrollingTarget {
            MyLog("SWView handlePan continuous \(self.book.pageIndex) to \(target) [\(recognizer.state.rawValue)]", level:1)
            self.adjustIndex(target)
            self.fAdvancing = false
            self.scrollingTarget = nil
        } else {
            MyLog("SWView handlePan normal \(self.book.pageIndex) [\(recognizer.state.rawValue)]", level:2)
        }

        let offset = self.book.horizontal ? CGPointMake((CGFloat(self.book.pageIndex) + ratio) * size.width, 0) : CGPointMake(0, (CGFloat(self.book.pageIndex) + ratio) * size.height)
        //MyLog("SwiftVC handlePan: \(recognizer.state.rawValue), \(ratio)")
        switch(recognizer.state) {
        case .Began:
            break
        case .Ended:
            //MyLog("SwiftVC handlePan: \(recognizer.velocityInView(self.view))")
            scrollView.contentOffset = offset
            var target = self.scrollIndex
            if target == self.book.pageIndex {
                let factor = CGFloat(0.3)
                if self.book.horizontal {
                    let extra = offset.x - CGFloat(target) * size.width - velocity.x * factor
                    if extra > size.width / 2.0 {
                        target += 1
                    } else if extra > 0 - size.width / 2 {
                        target -= 1
                    }
                } else {
                    let extra = offset.y - CGFloat(target) * size.height - velocity.y * factor
                    //MyLog("SwiftVC handlePan: \(Int(offset.y - CGFloat(target) * size.height)) - \(Int(velocity.y)) * \(factor) = \(Int(extra))")
                    if extra > size.height / 2 {
                        target += 1
                    } else if extra < 0 - size.height / 2 {
                        target -= 1
                    }
                }
            }
            target = min(max(target, 0), self.book.pages.count - 1)

            let offsetAligned = self.book.horizontal ? CGPointMake(size.width * CGFloat(target), 0) : CGPointMake(0, size.height * CGFloat(target))
            if target != self.book.pageIndex {
                // Paging was initiated by the swiping (forward or backward)
                self.book.currenPage.willLeave(fAdvancing)
                let page = self.book.pages[target]
                fAdvancing = target > self.book.pageIndex
                page.willEnter(fAdvancing)
                scrollingTarget = target
                MyLog("SWView handlePan paging \(self.book.pageIndex) to \(target), c=\(scrollingCount+1)", level:1)
            } else {
                if !self.book.horizontal && offset.y < -size.height/8.0
                   || self.book.horizontal && offset.x < -size.width/8.0 {
                    MyLog("SWView underscrolling detected \(offset.x), \(offset.y)", level:1)
                    let page = self.book.currenPage
                    page.willLeave(false)
                    page.willEnter(true)
                    page.didEnter(true)
                } else {
                    MyLog("SWView scrolling back c=\(scrollingCount+1)", level:1)
                }
            }
            self.scrollingCount += 1
            MyLog("SWView scrollling to \(offsetAligned)", level:1)
            scrollView.setContentOffset(offsetAligned, animated: true)
            break
        case .Changed:
            MyLog("SWView scrolls to \(offset)", level:1)
            scrollView.contentOffset = offset
            break
        case .Cancelled:
            break
        default:
            break
        }
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        MyLog("SWView  scrollViewWillBeginDragging was called")
    }
    func scrollViewDidEndDragging(scrollView: UIScrollView,
                        willDecelerate decelerate: Bool) {
        MyLog("SWView  scrollViewDidEndDragging was called")
    }
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        MyLog("SWView  scrollViewWillBeginDecelerating was called")
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        MyLog("SWView  scrollViewDidEndDecelerating was called")
    }
    
    func scrollViewShouldScrollToTop(scrollView: UIScrollView) -> Bool {
        MyLog("SWView  scrollViewShouldScrollToTop was called")
        return true
    }
#endif
    
    private func removeViewAtIndex(index:Int) {
        if index >= 0 && index < book.pages.count {
            let page = book.pages[index]
            page.unloadView()
        }
    }
    
    private func adjustIndex(newPageIndex:Int, fForced:Bool = false, fDeferredEnter:Bool = false) -> Bool {
        if self.book.pages.count == 0 {
            print("SwipeVC ### No Pages")
            return false
        }
        
        if newPageIndex == self.book.pageIndex && !fForced {
            return false
        }
        
        if !fForced {
            let pagePrev = self.book.currenPage
            pagePrev.didLeave(newPageIndex < self.book.pageIndex)
        }
    
        for i in -2...2 {
            let index = self.book.pageIndex - i
            if index < newPageIndex - 2 || index > newPageIndex + 2 || fForced {
                removeViewAtIndex(index)
            }
        }
        self.book.pageIndex = newPageIndex
        self.preparePages { (index:Int) -> (Void) in
            if fDeferredEnter && newPageIndex == index && newPageIndex == self.book.pageIndex {
                print("SwipeVC index=\(index)")
                if fForced {
                    self.book.currenPage.willEnter(true)
                }
                self.book.currenPage.didEnter(self.fAdvancing || fForced)
            }
        }
        
        if !fDeferredEnter {
            if fForced {
                self.book.currenPage.willEnter(true)
            }
            self.book.currenPage.didEnter(fAdvancing || fForced)
        }
        return true
    }

    private func preparePages(callback:((Int)->(Void))?) {
        func preparePage(index:Int, frame:CGRect) {
            if index < 0 || index >= book.pages.count {
                return
            }
            
            let page = self.book.pages[index]
            var above:UIView?
            if index > 0 {
                let pagePrev = self.book.pages[index-1]
                above = pagePrev.view
            }

            if let view = page.view {
                if let aboveSubview = above {
                    scrollView.insertSubview(view, aboveSubview: aboveSubview)
                }
            } else {
                let view = page.loadView({ (Void) -> (Void) in
                    callback?(index)
                })
                view.frame = frame
                
                if let aboveSubview = above {
                    scrollView.insertSubview(view, aboveSubview: aboveSubview)
                } else {
                    scrollView.addSubview(view)
                }
            }
            page.prepare()
        }
    
        var rc = scrollView.bounds
        let d = book.horizontal ? CGPointMake(rc.size.width, 0.0) : CGPointMake(0.0, rc.size.height)
        rc.origin = CGPointMake(d.x * CGFloat(self.book.pageIndex), d.y * CGFloat(self.book.pageIndex))
        
        for i in -2...2 {
            preparePage(self.book.pageIndex + i, frame: CGRectOffset(rc, CGFloat(i) * d.x, CGFloat(i) * d.y))
        }

        //MyLog("SWView tags=\(tags), \(pageIndex)")
        self.book.setActivePage(self.book.currenPage)

        // debugging
        _ = tagsString()
        
    }

    //
    // EXPERIMENTAL: Public interface, which allows applications to scroll it to a particular scrolling position. Notice that it will play "scroll" animations, but not "auto" animations.
    //
    func scrollTo(amount:CGFloat) {
        let pageIndex = Int(amount)
        if pageIndex < self.book.pages.count {
            let frame = scrollView.frame
            let rem = amount - CGFloat(pageIndex)
            adjustIndex(pageIndex, fForced: false, fDeferredEnter: false)
            let offset = self.book.horizontal ? CGPointMake((CGFloat(self.book.pageIndex) + rem) * frame.size.width, 0) : CGPointMake(0, (CGFloat(self.book.pageIndex) + rem) * frame.size.height)
            scrollView.contentOffset = offset
        }
    }
}
