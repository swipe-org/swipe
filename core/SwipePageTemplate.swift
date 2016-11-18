//
//  SwipePageTemplate.swift
//  Swipe
//
//  Created by satoshi on 9/8/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
//public typealias UIColor = NSColor
//public typealias UIFont = NSFont
#else
import UIKit
#endif
import AVFoundation

private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipePageTemplate: NSObject, AVAudioPlayerDelegate {
    let pageTemplateInfo:[String:Any]
    private let baseURL:URL?
    private let name:String
    private var bgmPlayer:AVAudioPlayer?
    private var fDebugEntered = false

    lazy var resourceURLs:[URL:String] = {
        var urls = [URL:String]()
        if let value = self.pageTemplateInfo["bgm"] as? String,
            let url = URL.url(value, baseURL: self.baseURL) {
            urls[url] = ""
        }
        return urls
    }()
    
    init(name:String, info:[String:Any], baseURL:URL?) {
        self.baseURL = baseURL
        self.name = name
        self.pageTemplateInfo = info
    }
    
    // This function is called when a page associated with this pageTemplate is activated (entered)
    //  AND the previous page is NOT associated with this pageTemplate object.
    func didEnter(_ prefetcher:SwipePrefetcher) {
        assert(fDebugEntered == false, "re-entering")
        fDebugEntered = true
        
        if let value = self.pageTemplateInfo["bgm"] as? String,
            let urlRaw = URL.url(value, baseURL: baseURL),
            let url = prefetcher.map(urlRaw) {
            MyLog("SWPageTemplate didEnter with bgm=\(value)", level:1)
            SwipeAssetManager.sharedInstance().loadAsset(url, prefix: "", bypassCache:false, callback: { (urlLocal:URL?, _) -> Void in
                if self.fDebugEntered,
                    let urlL = urlLocal,
                    let player = try? AVAudioPlayer(contentsOf: urlL) {
                    player.delegate = self
                    player.play()
                    self.bgmPlayer = player
                }
            })
        } else {
            //NSLog("SWPageTemplate didEnter failed to create URL")
        }
    }

    // This function is called when a page associated with this pageTemplate is deactivated (leaved)
    //  AND the subsequent page is not associated with this pageTemplate object.
    func didLeave() {
        assert(fDebugEntered == true, "leaving without entering")
        fDebugEntered = false

        if let player = bgmPlayer {
            player.stop()
            player.delegate = nil
            bgmPlayer = nil
        }
    }

    // We repeat the bgm
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let player = bgmPlayer {
            if flag {
                player.play()
            }
        }
    }
}
