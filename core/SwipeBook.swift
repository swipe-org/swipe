//
//  SwipeBook.swift
//  Swipe
//
//  Created by satoshi on 6/2/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

import AVFoundation

private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

protocol SwipeBookDelegate: NSObjectProtocol {
    func tapped()
}

class SwipeBook: NSObject, SwipePageDelegate {
    // Public properties
    var viewSize:CGSize?
    var pageIndex = 0
    var langId = "en"
    weak var delegate:SwipeBookDelegate!

    // Private properties
    private let bookInfo:[String:Any]
    private let url:URL?
    private var pageTemplateActive:SwipePageTemplate?

    //
    // Calculated properties (Public)
    //
    var currentPage:SwipePage {
        return self.pages[self.pageIndex]
    }
    //
    // Lazy properties (Public)
    //
    private lazy var langs:[[String:Any]]? = {
        return self.bookInfo["languages"] as? [[String:Any]]
    }()
    func languages() -> [[String:Any]]? {
        return self.langs
    }
    
    private (set) lazy var version:String? = {
        if let version = self.bookInfo["version"] as? String {
            return version
        }
        return nil
    }()
    
    lazy var title:String? = {
        if let title = self.bookInfo["title"] as? String {
            return title
        }
        return nil
    }()

    lazy var horizontal:Bool = {
        return self.paging == "leftToRight"
    }()

    lazy var orientation:String = {
        if let orientation = self.bookInfo["orientation"] as? String {
            return orientation
        }
        return "portrait"
    }()
    
    lazy var landscape:Bool = {
        return self.orientation == "landscape"
    }()
    
    lazy var viewstate:Bool = {
        if let state = self.bookInfo["viewstate"] as? Bool {
            return state
        }
        return true
    }()
    
    lazy var pages:[SwipePage] = {
        var pages = [SwipePage]()
        if let pageInfos = self.bookInfo["pages"] as? [[String:Any]] {
            for (index, pageInfo) in pageInfos.enumerated() {
                let page = SwipePage(index:index, info: pageInfo, delegate: self)
                pages.append(page)
            }
        }
        return pages
    }()
    
    //
    // Lazy properties (Private)
    //
    private lazy var templates:[String:Any] = {
        if let templates = self.bookInfo["templates"] as? [String:Any] {
            return templates
        }
        return [String:Any]()
    }()
    
    private lazy var templateElements:[String:Any] = {
        if let elements = self.templates["elements"] as? [String:Any] {
            return elements
        }
        else if let elements = self.bookInfo["elements"] as? [String:Any] {
            MyLog("DEPRECATED named elements; use 'templates'")
            return elements
        }
        return [String:Any]()
    }()

    private lazy var templatePages:[String:SwipePageTemplate] = {
        var ret = [String:SwipePageTemplate]()
        if let pages = self.templates["pages"] as? [String:[String:Any]] {
            for (key, info) in pages {
                ret[key] = SwipePageTemplate(name:key, info: info, baseURL:self.url)
            }
        }
        else if let pageTemplates = self.bookInfo["scenes"] as? [String:[String:Any]] {
            MyLog("DEPRECATED scenes; use 'templates'")
            for (key, info) in pageTemplates {
                ret[key] = SwipePageTemplate(name:key, info: info, baseURL:self.url)
            }
        }
        return ret
    }()

    private lazy var namedPaths:[String:Any] = {
        if let paths = self.bookInfo["paths"] as?[String:Any] {
            return paths
        }
        return [String:Any]()
    }()
    
    private lazy var paging:String = {
        if let paging = self.bookInfo["paging"] as? String {
            return paging
        }
        return "vertical"
    }()
    
    lazy var backgroundColor:CGColor = {
        if let value = self.bookInfo["bc"] as? String {
            return SwipeParser.parseColor(value)
        }
        return UIColor.black.cgColor
    }()
    
    lazy var dimension:CGSize = {
        let size = UIScreen.main.bounds.size
        if let dimension = self.bookInfo["dimension"] as? [CGFloat] {
            if dimension.count == 2 {
                if dimension[0] == 0.0 {
                    return CGSize(width: dimension[1] / size.height * size.width, height: dimension[1])
                } else if dimension[1] == 0.0 {
                    return CGSize(width: dimension[0], height: dimension[0] / size.width * size.height)
                }
                return CGSize(width: dimension[0], height: dimension[1])
            }
        }
        return size
    }()
    
    lazy private var scale:CGSize = {
        if let size = self.viewSize {
            let scale = size.width / self.dimension.width
            return CGSize(width: scale, height: scale)
        }
        return CGSize(width: 1.0, height: 1.0)
    }()

    lazy private var markdown:SwipeMarkdown = {
        let info = self.bookInfo["markdown"] as? [String:Any]
        let markdown = SwipeMarkdown(info:info, scale:self.scale, dimension:self.dimension)
        return markdown
    }()
    
    lazy private var voices:[String:[String:Any]] = {
        if let info = self.bookInfo["voices"] as? [String:[String:Any]] {
            return info
        }
        return [String:[String:Any]]()
    }()
    
    // Initializer/Deinitializer
    /*
    init?(url:URL) {
        self.url = url
        if let data = NSData(contentsOfURL: url),
               script = (try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)) as? [String:Any] {
            self.bookInfo = script
            super.init()
        } else {
            self.bookInfo = [String:Any]()
            super.init()
            return nil
        }
    }
    */

    init?(bookInfo:[String:Any], url:URL?, delegate:SwipeBookDelegate) {
        self.url = url
        self.bookInfo = bookInfo
        self.delegate = delegate
    }
    
    deinit {
        MyLog("SwipeBook deinit", level:1)
    }
    
    // <SwipePageDelegate> method
    func dimension(_ page:SwipePage) -> CGSize {
        return self.dimension
    }

    // <SwipePageDelegate> method
    func scale(_ page:SwipePage) -> CGSize {
        return self.scale
    }
    
    // <SwipePageDelegate> method
    func prototypeWith(_ name:String?) -> [String:Any]? {
        if let key = name,
           let value = self.templateElements[key] as? [String:Any] {
            return value
        }
        return nil
    }
    
    // <SwipePageDelegate> method
    func pageTemplateWith(_ name:String?) -> SwipePageTemplate? {
        let key = (name == nil) ? "*" : name!
        if let value = self.templatePages[key] {
            return value
        }
        return nil
    }

    // <SwipePageDelegate> method
    func pathWith(_ name:String?) -> Any? {
        if let key = name,
           let value = self.namedPaths[key] {
            return value
        }
        return nil
    }
    
    // <SwipePageDelegate> method
    func tapped() {
        delegate.tapped()
    }

#if !os(OSX) // REVIEW
    // <SwipePageDelegate> method
    func speak(_ utterance:AVSpeechUtterance) {
        MyLog("SwipeBook speak", level:2)
        let synthesizer = SwipeSymthesizer.sharedInstance().synthesizer()
        synthesizer.speak(utterance)
    }

    // <SwipePageDelegate> method
    func stopSpeaking() {
        MyLog("SwipeBook stop", level:2)
        let synthesizer = SwipeSymthesizer.sharedInstance().synthesizer()
        synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
    }
#endif

    // <SwipePageDelegate> method
    func baseURL() -> URL? {
        return url
    }
    
    // <SwipePageDelegate> method
    func voice(_ k:String?) -> [String:Any] {
        let key = (k == nil) ? "*" : k!
        if let voice = voices[key] {
            return voice
        }
        return [String:Any]()
    }

    // <SwipePageDelegate> method
    func languageIdentifier() -> String? {
        return langId
    }

    func sourceCode() -> String {
        if let url = self.url {
            let data = try? Data(contentsOf: url)
            return NSString(data: data!, encoding: String.Encoding.utf8.rawValue) as! String
        }
        return "N/A"
    }
    
    func setActivePage(_ page:SwipePage) {
        if self.pageTemplateActive != page.pageTemplate {
            MyLog("SwipeBook setActive \(self.pageTemplateActive), \(page.pageTemplate)", level:1)
            if let pageTemplate = self.pageTemplateActive {
                pageTemplate.didLeave()
            }
            if let pageTemplate = page.pageTemplate {
                pageTemplate.didEnter(page.prefetcher)
            }
            self.pageTemplateActive = page.pageTemplate
        }
    }

    func currentPageIndex() -> Int {
        return self.pageIndex
    }

    func parseMarkdown(_ markdowns:[String]) -> NSAttributedString {
        return self.markdown.parse(markdowns)
    }
}
