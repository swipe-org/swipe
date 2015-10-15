//
//  SwipeScene.swift
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

class SwipeScene: NSObject, AVAudioPlayerDelegate {
    let sceneInfo:[String:AnyObject]
    private let baseURL:NSURL?
    private let name:String
    private var bgmPlayer:AVAudioPlayer?
    private var fDebugEntered = false

    lazy var resourceURLs:[NSURL:String] = {
        var urls = [NSURL:String]()
        if let value = self.sceneInfo["bgm"] as? String,
               url = NSURL.url(value, baseURL: self.baseURL) {
            urls[url] = ""
        }
        return urls
    }()
    
    init(name:String, info:[String:AnyObject], baseURL:NSURL?) {
        self.baseURL = baseURL
        self.name = name
        self.sceneInfo = info
    }
    
    // This function is called when a page associated with this scene is activated (entered)
    //  AND the previous page is NOT associated with this scene object.
    func didEnter() {
        assert(fDebugEntered == false, "re-entering")
        fDebugEntered = true
        
        if let value = self.sceneInfo["bgm"] as? String,
               url = NSURL.url(value, baseURL: baseURL) {
            NSLog("SWScene didEnter with bgm=\(value)")
            SwipeAssetManager.sharedInstance().loadAsset(url, prefix: "", callback: { (urlLocal:NSURL?, _:NSError!) -> Void in
                if self.fDebugEntered,
                   let urlL = urlLocal,
                       player = try? AVAudioPlayer(contentsOfURL: urlL) {
                    player.delegate = self
                    player.play()
                    self.bgmPlayer = player
                }
            })
        } else {
            //NSLog("SWScene didEnter failed to create URL")
        }
    }

    // This function is called when a page associated with this scene is deactivated (leaved)
    //  AND the subsequent page is not associated with this scene object.
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
