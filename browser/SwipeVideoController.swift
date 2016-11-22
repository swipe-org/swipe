//
//  SwipeVideoController.swift
//  iheadunit
//
//  Created by satoshi on 11/22/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class SwipeVideoController: UIViewController {
    fileprivate var document:[String:Any]?
    fileprivate weak var delegate:SwipeDocumentViewerDelegate?
    fileprivate var url:URL?
    fileprivate var videoURL:URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension SwipeVideoController: SwipeDocumentViewer {
    func documentTitle() -> String? {
        return document?["title"] as? String
    }
    
    func loadDocument(_ document:[String:Any], size:CGSize, url:URL?, state:[String:Any]?, callback:@escaping (Float, NSError?)->(Void)) throws {
        self.document = document
        self.url = url
        if let filename = document["video"] as? String {
            videoURL = Bundle.main.url(forResource: filename, withExtension: nil)
        } else {
            throw SwipeError.invalidDocument
        }
        callback(1.0, nil)
    }
    
    func hideUI() -> Bool {
        return false
    }
    
    func landscape() -> Bool {
        return false // we might want to change it later
    }
    
    func setDelegate(_ delegate:SwipeDocumentViewerDelegate) {
        self.delegate = delegate
    }
    
    func becomeZombie() {
        // no op
    }
    
    func saveState() -> [String:Any]? {
        return nil
    }
    
    func languages() -> [[String:Any]]? {
        return nil
    }
    
    func reloadWithLanguageId(_ langId:String) {
        // no op
    }
}
