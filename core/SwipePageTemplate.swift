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

private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

class SwipePageTemplate: NSObject, AVAudioPlayerDelegate {
    let pageTemplateInfo:[String:AnyObject]
    private let baseURL:NSURL?
    private let name:String
    private var bgmPlayer:AVAudioPlayer?
    private var fDebugEntered = false

    lazy var resourceURLs:[NSURL:String] = {
        var urls = [NSURL:String]()
        if let value = self.pageTemplateInfo["bgm"] as? String,
               url = NSURL.url(value, baseURL: self.baseURL) {
            urls[url] = ""
        }
        return urls
    }()
    
    init(name:String, info:[String:AnyObject], baseURL:NSURL?) {
        self.baseURL = baseURL
        self.name = name
        self.pageTemplateInfo = info
    }
    
    // This function is called when a page associated with this pageTemplate is activated (entered)
    //  AND the previous page is NOT associated with this pageTemplate object.
    func didEnter(prefetcher:SwipePrefetcher) {
        assert(fDebugEntered == false, "re-entering")
        fDebugEntered = true
        
        if let value = self.pageTemplateInfo["bgm"] as? String,
               urlRaw = NSURL.url(value, baseURL: baseURL),
               url = prefetcher.map(urlRaw) {
            MyLog("SWPageTemplate didEnter with bgm=\(value)", level:1)
            SwipeAssetManager.sharedInstance().loadAsset(url, prefix: "", bypassCache:false, callback: { (urlLocal:NSURL?, _:NSError!) -> Void in
                if self.fDebugEntered,
                   let urlL = urlLocal,
                       player = try? AVAudioPlayer(contentsOfURL: urlL) {
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
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if let player = bgmPlayer {
            if flag {
                player.play()
            }
        }
    }
}
