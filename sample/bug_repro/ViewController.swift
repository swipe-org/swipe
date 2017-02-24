//
//  ViewController.swift
//  bug_repro
//
//  Created by satoshi on 8/23/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit
import AVFoundation

//
// I reported this bug to Apple on August 25, 2016. Bug# 27982201.
//
class ViewController: UIViewController {
    @IBOutlet var viewMain:UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let urlVideo = Bundle.main.url(forResource: "IMG_9401", withExtension: "mov") {
            let videoPlayer = AVPlayer(playerItem: AVPlayerItem(url: urlVideo))
            let videoLayer = AVPlayerLayer(player: videoPlayer)
            videoLayer.frame = viewMain.bounds
            viewMain.layer.addSublayer(videoLayer)
            videoPlayer.play()
        }
    }

    @IBAction func test() {
        UIGraphicsBeginImageContext(view.frame.size)
        if let layer = viewMain.layer.presentation() {
            layer.render(in: UIGraphicsGetCurrentContext()!)
        }
        UIGraphicsEndImageContext()
    }
}

