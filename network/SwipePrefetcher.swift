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


private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipePrefetcher {
    private var urls = [URL:String]()
    private var urlsFetching = [URL]()
    private var urlsFetched = [URL:URL]()
    private var urlsFailed = [URL]()
    private var errors = [NSError]()
    private var fComplete = false
    private var _progress = Float(0)
    
    var progress:Float {
        return _progress
    }
    
    init(urls:[URL:String]) {
        self.urls = urls
    }
    
    func start(_ callback:@escaping (Bool, [URL], [NSError]) -> Void) {
        if fComplete {
            MyLog("SWPrefe already completed", level:1)
            callback(true, self.urlsFailed, self.errors)
            return
        }
        
        let manager = SwipeAssetManager.sharedInstance()
        var count = 0
        _progress = 0
        let fileManager = FileManager.default
        for (url,prefix) in urls {
            if url.scheme == "file" {
                if fileManager.fileExists(atPath: url.path) {
                    urlsFetched[url] = url
                } else {
                    // On-demand resource support
                    urlsFetched[url] = Bundle.main.url(forResource: url.lastPathComponent, withExtension: nil)
                    MyLog("SWPrefe onDemand resource at \(urlsFetched[url]) instead of \(url)", level:1)
                }
            } else {
                count += 1
                urlsFetching.append(url)
                manager.loadAsset(url, prefix: prefix, bypassCache:false, callback: { (urlLocal:URL?, error:NSError?) -> Void in
                    if let urlL = urlLocal {
                        self.urlsFetched[url] = urlL
                    } else {
                        self.urlsFailed.append(url)
                        if let error = error {
                            self.errors.append(error)
                        }
                    }
                    count -= 1
                    if (count == 0) {
                        self.fComplete = true
                        self._progress = 1
                        MyLog("SWPrefe completed \(self.urlsFetched.count)", level: 1)
                        callback(true, self.urlsFailed, self.errors)
                    } else {
                        self._progress = Float(self.urls.count - count) / Float(self.urls.count)
                        callback(false, self.urlsFailed, self.errors)
                    }
                })
            }
        }
        if count == 0 {
            self.fComplete = true
            self._progress = 1
            callback(true, urlsFailed, errors)
        }
    }
    
    func append(_ urls:[URL:String], callback:@escaping (Bool, [URL], [NSError]) -> Void) {
        let manager = SwipeAssetManager.sharedInstance()
        var count = 0
        _progress = 0
        let fileManager = FileManager.default
        for (url,prefix) in urls {
            self.urls[url] = prefix
            if url.scheme == "file" {
                if fileManager.fileExists(atPath: url.path) {
                    urlsFetched[url] = url
                } else {
                    // On-demand resource support
                    urlsFetched[url] = Bundle.main.url(forResource: url.lastPathComponent, withExtension: nil)
                    MyLog("SWPrefe onDemand resource at \(urlsFetched[url]) instead of \(url)", level:1)
                }
            } else {
                count += 1
                urlsFetching.append(url)
                manager.loadAsset(url, prefix: prefix, bypassCache:false, callback: { (urlLocal:URL?, error:NSError?) -> Void in
                    if let urlL = urlLocal {
                        self.urlsFetched[url] = urlL
                    } else if let error = error {
                        self.urlsFailed.append(url)
                        self.errors.append(error)
                    }
                    count -= 1
                    if (count == 0) {
                        self.fComplete = true
                        self._progress = 1
                        MyLog("SWPrefe completed \(self.urlsFetched.count)", level: 1)
                        callback(true, self.urlsFailed, self.errors)
                    } else {
                        self._progress = Float(self.urls.count - count) / Float(self.urls.count)
                        callback(false, self.urlsFailed, self.errors)
                    }
                })
            }
        }
        if count == 0 {
            self.fComplete = true
            self._progress = 1
            callback(true, urlsFailed, errors)
        }
    }
    func map(_ url:URL) -> URL? {
        return urlsFetched[url]
    }
    
    static func extensionForType(_ memeType:String) -> String {
        let ext:String
        if memeType == "video/quicktime" {
            ext = ".mov"
        } else if memeType == "video/mp4" {
            ext = ".mp4"
        } else {
            ext = ""
        }
        return ext
    }
    
    static func isMovie(_ mimeType:String) -> Bool {
        return mimeType == "video/quicktime" || mimeType == "video/mp4"
    }
}
