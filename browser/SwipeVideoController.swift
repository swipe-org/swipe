//
//  SwipeVideoController.swift
//  iheadunit
//
//  Created by satoshi on 11/22/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit
import AVFoundation

class SwipeVideoController: UIViewController {
    fileprivate var document = [String:Any]()
    fileprivate var pages = [[String:Any]]()
    fileprivate weak var delegate:SwipeDocumentViewerDelegate?
    fileprivate var url:URL?
    fileprivate let videoPlayer = AVPlayer()
    fileprivate var videoLayer:AVPlayerLayer!
    fileprivate var index = 0
    fileprivate var observer:Any?
    
    deinit {
        print("deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        videoLayer = AVPlayerLayer(player: self.videoPlayer)
        view.layer.addSublayer(self.videoLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.videoLayer.frame = view.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension SwipeVideoController: SwipeDocumentViewer {
    func documentTitle() -> String? {
        return document["title"] as? String
    }
    
    func loadDocument(_ document:[String:Any], size:CGSize, url:URL?, state:[String:Any]?, callback:@escaping (Float, NSError?)->(Void)) throws {
        self.document = document
        self.url = url
        guard let filename = document["video"] as? String,
              let pages = document["pages"] as? [[String:Any]] else {
            throw SwipeError.invalidDocument
        }
        self.pages = pages

        guard let videoURL = Bundle.main.url(forResource: filename, withExtension: nil) else {
            return
        }
        let playerItem = AVPlayerItem(url:videoURL)
        videoPlayer.replaceCurrentItem(with: playerItem)
        
        callback(1.0, nil)
    }
    
    func hideUI() -> Bool {
        return true
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
    
    private func removeObserver() {
        if let observer = self.observer {
            videoPlayer.removeTimeObserver(observer)
            self.observer = nil
            print("remove observer")
        }
    }

    func moveToPageAt(index:Int) {
        print("moveToPageAt", index)
        if index < pages.count {
            self.index = index
            let page = pages[self.index]
            let start = page["start"] as? Double ?? 0.0
            let duration = page["duration"] as? Double ?? 0.0
            let videoPlayer = self.videoPlayer // local
            guard let playerItem = videoPlayer.currentItem else {
                return // something is wrong
            }

            removeObserver()
            let time = CMTime(seconds: start, preferredTimescale: 600)
            playerItem.seek(to: time) { (success) in
                //print("seek complete", success)
                if duration > 0 {
                    videoPlayer.play()
                    let end = CMTime(seconds: start + duration, preferredTimescale: 600)
                    self.observer = videoPlayer.addBoundaryTimeObserver(forTimes: [end as NSValue], queue: nil) { [weak self] in
                        print("pausing", index)
                        videoPlayer.pause()
                        self?.removeObserver()
                    }
                }
            }
        }
    }
    func pageIndex() -> Int? {
        return index
    }
    func pageCount() -> Int? {
        return pages.count
    }
}
