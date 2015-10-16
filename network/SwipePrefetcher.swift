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
    let s_verbosLevel = 1
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
    
    func start(callback:([NSURL], [NSError]) -> Void) {
        if fComplete {
            MyLog("SWPrefe already completed", level:1)
            callback(self.urlsFailed, self.errors)
        }
        
        let manager = SwipeAssetManager.sharedInstance()
        var count = 0
        for (url,prefix) in urls {
            if url.scheme == "file" {
                urlsFetched[url] = url
            } else {
                count++
                urlsFetching.append(url)
                manager.loadAsset(url, prefix: prefix, callback: { (urlLocal:NSURL?, error:NSError!) -> Void in
                    if let urlL = urlLocal {
                        self.urlsFetched[url] = urlL
                    } else {
                        self.urlsFailed.append(url)
                        self.errors.append(error)
                    }
                    count--
                    if (count == 0) {
                        self.fComplete = true
                        NSLog("SWPrefe complete \(self.urlsFetched.count)")
                        callback(self.urlsFailed, self.errors)
                    }
                })
            }
        }
        if count == 0 {
            self.fComplete = true
            callback(urlsFailed, errors)
        }
    }
    
    func map(url:NSURL) -> NSURL? {
        return urlsFetched[url]
    }
}
