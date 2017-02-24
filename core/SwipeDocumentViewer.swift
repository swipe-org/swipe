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
    func loadDocument(_ document:[String:Any], size:CGSize, url:URL?, state:[String:Any]?, callback:@escaping (Float, NSError?)->(Void)) throws
    func hideUI() -> Bool
    func landscape() -> Bool
    func setDelegate(_ delegate:SwipeDocumentViewerDelegate)
    func becomeZombie()
    func saveState() -> [String:Any]?
    func languages() -> [[String:Any]]?
    func reloadWithLanguageId(_ langId:String)
    func moveToPageAt(index:Int)
    func pageIndex() -> Int?
    func pageCount() -> Int?
}

enum SwipeError: Swift.Error {
    case invalidDocument
}
