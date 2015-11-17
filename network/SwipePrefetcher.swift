//
//  SwipePrefetcher.swift
//  sample
//
//  Created by satoshi on 10/12/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif


private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipePrefetcher {
    private let urls:[NSURL:String]
    private var urlsFetching = [NSURL]()
    private var urlsFetched = [NSURL:NSURL]()
    private var urlsFailed = [NSURL]()
    private var errors = [NSError]()
    private var fComplete = false
    
    init(urls:[NSURL:String]) {
        self.urls = urls
    }
    
    func start(callback:(Bool, [NSURL], [NSError]) -> Void) {
        if fComplete {
            MyLog("SWPrefe already completed", level:1)
            callback(true, self.urlsFailed, self.errors)
            return
        }
        
        let manager = SwipeAssetManager.sharedInstance()
        var count = 0
        let fileManager = NSFileManager.defaultManager()
        for (url,prefix) in urls {
            if url.scheme == "file" {
                if fileManager.fileExistsAtPath(url.path!) {
                    urlsFetched[url] = url
                } else {
                    // On-demand resource support
                    urlsFetched[url] = NSBundle.mainBundle().URLForResource(url.lastPathComponent, withExtension: nil)
                    MyLog("SWPrefe onDemand resource at \(urlsFetched[url]) instead of \(url)", level:1)
                }
            } else {
                count++
                urlsFetching.append(url)
                manager.loadAsset(url, prefix: prefix, bypassCache:false, callback: { (urlLocal:NSURL?, error:NSError!) -> Void in
                    if let urlL = urlLocal {
                        self.urlsFetched[url] = urlL
                    } else {
                        self.urlsFailed.append(url)
                        self.errors.append(error)
                    }
                    count--
                    if (count == 0) {
                        self.fComplete = true
                        MyLog("SWPrefe completed \(self.urlsFetched.count)", level: 1)
                        callback(true, self.urlsFailed, self.errors)
                    }
                })
            }
        }
        if count == 0 {
            self.fComplete = true
            callback(true, urlsFailed, errors)
        }
    }
    
    func map(url:NSURL) -> NSURL? {
        return urlsFetched[url]
    }
}
