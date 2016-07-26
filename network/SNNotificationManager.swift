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
    
    func addObserverForName(_ name: NotificationNameConvertible?, object obj: AnyObject?, queue: OperationQueue?, usingBlock block: (Notification!) -> Void) {
        let observer = NotificationCenter.default.addObserver(forName: name?.notificationName, object: obj, queue: queue, using: block)
        observers.append(observer)
    }
    
    func clear() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

protocol NotificationNameConvertible {
    var notificationName: Notification.Name { get }
}

extension String: NotificationNameConvertible {
    var notificationName: Notification.Name {
        return Notification.Name(rawValue: self)
    }
}

extension Notification.Name: NotificationNameConvertible {
    var notificationName: Notification.Name {
        return self
    }
}
