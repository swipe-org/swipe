//
//  ViewController.swift
//  bug_repro
//
//  Created by satoshi on 8/23/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let videoPlayer = AVPlayer()
        let videoLayer = AVPlayerLayer(player: videoPlayer)
        videoLayer.frame = self.view.frame
        view.layer.addSublayer(videoLayer)

        let urlVideo = NSBundle.mainBundle().URLForResource("IMG_9401", withExtension: "mov")!

        let playerItem = AVPlayerItem(URL: urlVideo)
        videoPlayer.replaceCurrentItemWithPlayerItem(playerItem)
        videoPlayer.seekToTime(kCMTimeZero)
        videoPlayer.play()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

