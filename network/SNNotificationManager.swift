//
//  SNNotificationManager.swift
//
//  Created by satoshi on 3/30/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

class SNNotificationManager {
    var observers = [NSObjectProtocol]()
    
    deinit {
        clear()
    }
    
    func addObserverForName(name: String?, object obj: AnyObject?, queue: NSOperationQueue?, usingBlock block: (NSNotification!) -> Void) {
        let observer = NSNotificationCenter.defaultCenter().addObserverForName(name, object: obj, queue: queue, usingBlock: block)
        observers.append(observer)
    }
    
    func clear() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
}
