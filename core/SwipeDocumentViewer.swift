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
    func browseTo(_ url:URL)
    func tapped()
}

protocol SwipeDocumentViewer {
    func documentTitle() -> String?
    func loadDocument(_ document:[String:AnyObject], size:CGSize, url:URL?, state:[String:AnyObject]?, callback:@escaping (Float, NSError?)->(Void)) throws
    func hideUI() -> Bool
    func landscape() -> Bool
    func setDelegate(_ delegate:SwipeDocumentViewerDelegate)
    func becomeZombie()
    func saveState() -> [String:AnyObject]?
    func languages() -> [[String:AnyObject]]?
    func reloadWithLanguageId(_ langId:String)
}

enum SwipeError: Swift.Error {
    case invalidDocument
}
