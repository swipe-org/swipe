//
//  SwipeConnection.swift
//  sample
//
//  Created by satoshi on 10/9/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

import CoreData

private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 1
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipeConnection: NSObject {
    private static var connections = [NSURL:SwipeConnection]()
    static let session:NSURLSession = {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.URLCache = nil // disable cache by NSURLSession (because we do)
        return NSURLSession(configuration: config, delegate: nil, delegateQueue: NSOperationQueue.mainQueue())
    }()
    static func connection(url:NSURL, urlLocal:NSURL, entity:NSManagedObject) -> SwipeConnection {
        if let connection = connections[url] {
            return connection
        }
        let connection = SwipeConnection(url: url, urlLocal: urlLocal, entity:entity)
        //connection.start()
        let session = SwipeConnection.session
        let start = NSDate()
        let task = session.downloadTaskWithURL(url) { (urlTemp:NSURL?, res:NSURLResponse?, error:NSError?) -> Void in
            assert(NSThread.currentThread() == NSThread.mainThread(), "thread error")
            let duration = NSDate().timeIntervalSinceDate(start)
            if let urlT = urlTemp {
                if let httpRes = res as? NSHTTPURLResponse {
                    if httpRes.statusCode == 200 {
                        let fm = NSFileManager.defaultManager()
                        do {
                            let attr = try fm.attributesOfItemAtPath(urlT.path!)
                            if let size = attr[NSFileSize] as? Int {
                                connection.fileSize = size
                                SwipeAssetManager.sharedInstance().wasFileLoaded(connection)
                            }
                        } catch {
                            MyLog("SWConn  failed to get attributes (but ignored)")
                        }
                        MyLog("SWConn  loaded \(url.lastPathComponent!) in \(duration)s (\(connection.fileSize))", level:1)
                        do {
                            if fm.fileExistsAtPath(urlLocal.path!) {
                                try fm.removeItemAtURL(urlLocal)
                            }
                            try fm.copyItemAtURL(urlT, toURL: urlLocal)
                        } catch {
                            connection.callbackAll(error as NSError)
                            return
                        }
                    } else {
                        MyLog("SWConn  HTTP error (\(url.lastPathComponent!), \(httpRes.statusCode))")
                        connection.callbackAll(NSError(domain: NSURLErrorDomain, code: httpRes.statusCode, userInfo: nil))
                        return
                    }
                } else {
                    MyLog("SWConn  no HTTPURLResponse, something is wrong!")
                }
            } else {
                MyLog("SWConn  network error (\(url.lastPathComponent!), \(error))")
            }
            connection.callbackAll(error)
        }
        task.resume()
        return connection
    }
    let url, urlLocal:NSURL
    let entity:NSManagedObject
    var callbacks = Array<(NSError!) -> Void>()
    var fileSize = 0

    private init(url:NSURL, urlLocal:NSURL, entity:NSManagedObject) {
        self.url = url
        self.urlLocal = urlLocal
        self.entity = entity
        super.init()
        SwipeConnection.connections[url] = self
    }
    deinit {
        //MyLog("SWCon deinit \(url.lastPathComponent)")
    }

    func load(callback:(NSError!) -> Void) {
        callbacks.append(callback)
    }

    func callbackAll(error: NSError?) {
        SwipeConnection.connections.removeValueForKey(self.url)
        for callback in callbacks {
            callback(error)
        }
    }

}
