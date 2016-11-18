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

private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipeConnection: NSObject {
    private static var connections = [URL:SwipeConnection]()
    static let session:URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil // disable cache by URLSession (because we do)
        return URLSession(configuration: config, delegate: nil, delegateQueue: OperationQueue.main)
    }()
    static func connection(_ url:URL, urlLocal:URL, entity:NSManagedObject) -> SwipeConnection {
        if let connection = connections[url] {
            return connection
        }
        let connection = SwipeConnection(url: url, urlLocal: urlLocal, entity:entity)
        //connection.start()
        let session = SwipeConnection.session
        let start = Date()
        let task = session.downloadTask(with: url) { (urlTemp:URL?, res:URLResponse?, error:Swift.Error?) -> Void in
            assert(Thread.current == Thread.main, "thread error")
            let duration = Date().timeIntervalSince(start)
            if let urlT = urlTemp {
                if let httpRes = res as? HTTPURLResponse {
                    if httpRes.statusCode == 200 {
                        let fm = FileManager.default
                        do {
                            let attr = try fm.attributesOfItem(atPath: urlT.path)
                            if let size = attr[FileAttributeKey.size] as? Int {
                                connection.fileSize = size
                                SwipeAssetManager.sharedInstance().wasFileLoaded(connection)
                            }
                        } catch {
                            MyLog("SWConn  failed to get attributes (but ignored)")
                        }
                        MyLog("SWConn  loaded \(url.lastPathComponent) in \(duration)s (\(connection.fileSize))", level:1)
                        do {
                            if fm.fileExists(atPath: urlLocal.path) {
                                try fm.removeItem(at: urlLocal)
                            }
                            try fm.copyItem(at: urlT, to: urlLocal)
                        } catch {
                            connection.callbackAll(error as NSError)
                            return
                        }
                    } else {
                        MyLog("SWConn  HTTP error (\(url.lastPathComponent), \(httpRes.statusCode))")
                        connection.callbackAll(NSError(domain: NSURLErrorDomain, code: httpRes.statusCode, userInfo: nil))
                        return
                    }
                } else {
                    MyLog("SWConn  no HTTPURLResponse, something is wrong!")
                }
            } else {
                MyLog("SWConn  network error (\(url.lastPathComponent), \(error))")
            }
            connection.callbackAll(error as NSError?)
        }
        task.resume()
        return connection
    }
    let url, urlLocal:URL
    let entity:NSManagedObject
    var callbacks = Array<(NSError!) -> Void>()
    var fileSize = 0

    private init(url:URL, urlLocal:URL, entity:NSManagedObject) {
        self.url = url
        self.urlLocal = urlLocal
        self.entity = entity
        super.init()
        SwipeConnection.connections[url] = self
    }
    deinit {
        //MyLog("SWCon deinit \(url.lastPathComponent)")
    }

    func load(_ callback:@escaping (NSError!) -> Void) {
        callbacks.append(callback)
    }

    func callbackAll(_ error: NSError?) {
        SwipeConnection.connections.removeValue(forKey: self.url)
        for callback in callbacks {
            callback(error)
        }
    }

}
