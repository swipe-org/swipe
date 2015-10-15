//
//  SwipeDocumentViewer.swift
//  sample
//
//  Created by satoshi on 10/13/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

protocol SwipeDocumentViewerDelegate: NSObjectProtocol {
    func browseTo(url:NSURL)
}

protocol SwipeDocumentViewer {
    func documentTitle() -> String?
    func loadDocument(document:[String:AnyObject], url:NSURL?) throws
    func hideUI() -> Bool
    func landscape() -> Bool
    func setDelegate(delegate:SwipeDocumentViewerDelegate)
    func becomeZombie()
}

enum SwipeError: ErrorType {
    case InvalidDocument
}