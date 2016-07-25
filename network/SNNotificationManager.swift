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
    
    func addObserverForName(_ name: String?, object obj: AnyObject?, queue: OperationQueue?, usingBlock block: (Notification!) -> Void) {
        let observer = NotificationCenter.default.addObserver(forName: name.map { NSNotification.Name(rawValue: $0) }, object: obj, queue: queue, using: block)
        observers.append(observer)
    }
    
    func clear() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
