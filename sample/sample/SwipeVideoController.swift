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
    static var playerItemContext = "playerItemContext"
    fileprivate var document = [String:Any]()
    fileprivate var pages = [[String:Any]]()
    fileprivate weak var delegate:SwipeDocumentViewerDelegate?
    fileprivate var url:URL?
    fileprivate let videoPlayer = AVPlayer()
    fileprivate var videoLayer:AVPlayerLayer!
    fileprivate let overlayLayer = CALayer()
    fileprivate var index = 0
    fileprivate var observer:Any?
    fileprivate var layers = [String:CALayer]()
    fileprivate var dimension = CGSize(width:320, height:568)
    
    deinit {
        print("SVideoC deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        videoLayer = AVPlayerLayer(player: self.videoPlayer)
        overlayLayer.masksToBounds = true
        view.layer.addSublayer(self.videoLayer)
        view.layer.addSublayer(self.overlayLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let frame = CGRect(origin: .zero, size: dimension)
        self.videoLayer.frame = frame
        self.overlayLayer.frame = frame
        let viewSize = view.bounds.size
        let scale = min(viewSize.width / dimension.width,
                        viewSize.height / dimension.height)
        var xf = CATransform3DMakeScale(scale, scale, 0)
        xf = CATransform3DTranslate(xf,
            (viewSize.width - dimension.width) / 2.0 / scale,
            (viewSize.height - dimension.height) / 2.0 / scale, 0.0)
        self.videoLayer.transform = xf
        self.overlayLayer.transform = xf
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
        if let dimension = document["dimension"] as? [CGFloat],
           dimension.count == 2 {
           self.dimension = CGSize(width: dimension[0], height: dimension[1])
        }

        guard let videoURL = Bundle.main.url(forResource: filename, withExtension: nil) else {
            return
        }
        let playerItem = AVPlayerItem(url:videoURL)
        videoPlayer.replaceCurrentItem(with: playerItem)
        
        if let elements = document["elements"] as? [[String:Any]] {
            print("elements", elements)
            for element in elements {
                if let id = element["id"] as? String,
                   let h = element["h"] as? CGFloat,
                   let w = element["w"] as? CGFloat {
                   let layer = CALayer()
                   layer.frame = CGRect(origin: .zero, size: CGSize(width: w, height: h))
                   layer.backgroundColor = UIColor.blue.cgColor
                   layers[id] = layer
                }
            }
        }
        //moveToPageAt(index: 0)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &SwipeVideoController.playerItemContext)
        
        callback(1.0, nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                           of object: Any?,
                           change: [NSKeyValueChangeKey : Any]?,
                           context: UnsafeMutableRawPointer?) {
        guard context == &SwipeVideoController.playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItemStatus
            
            // Get the status change from the change dictionary
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over the status
            switch status {
            case .readyToPlay:
                print("ready")
                moveToPageAt(index: 0)
                if let playerItem = videoPlayer.currentItem {
                    playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &SwipeVideoController.playerItemContext)
                }
            default:
                break
            }
        }
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
            print("SVideoC remove observer")
        }
    }

    func moveToPageAt(index:Int) {
        print("SVideoC moveToPageAt", index)
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
            let tolerance = CMTimeMake(10, 600) // 1/60sec
            playerItem.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { (success) in
                //print("seek complete", success)
                if duration > 0 {
                    videoPlayer.play()
                    let end = CMTime(seconds: start + duration, preferredTimescale: 600)
                    self.observer = videoPlayer.addBoundaryTimeObserver(forTimes: [end as NSValue], queue: nil) { [weak self] in
                        print("SVideoC pausing", index)
                        videoPlayer.pause()
                        self?.removeObserver()
                    }
                }
            }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if let sublayers = overlayLayer.sublayers {
                for layer in sublayers {
                    layer.removeFromSuperlayer()
                }
            }
            if let elements = page["elements"] as? [[String:Any]] {
                for element in elements {
                    if let id = element["id"] as? String,
                       let layer = layers[id] {
                        layer.removeAllAnimations()
                        layer.transform = CATransform3DIdentity
                        let x = element["x"] as? CGFloat ?? 0
                        let y = element["y"] as? CGFloat ?? 0
                        let frame = CGRect(origin: CGPoint(x:x, y:y), size: layer.frame.size)
                        layer.frame = frame
                        layer.opacity = element["opacity"] as? Float ?? 1.0
                        overlayLayer.addSublayer(layer)
                        
                        if let to = element["to"] as? [String:Any] {
                            var beginTime:CFTimeInterval?
                            if let start = to["start"] as? Double {
                                beginTime = layer.convertTime(CACurrentMediaTime(), to: nil) + start
                            }
                            let aniDuration = to["duration"] as? Double ?? duration
                        
                            if let tx = to["translate"] as? [CGFloat], tx.count == 2 {
                                let ani = CABasicAnimation(keyPath: "transform")
                                let transform = CATransform3DMakeTranslation(tx[0], tx[1], 0.0)
                                ani.fromValue = CATransform3DIdentity as NSValue
                                ani.toValue = transform as NSValue // NSValue(caTransform3D : transform)
                                ani.fillMode = kCAFillModeBoth
                                if let beginTime = beginTime {
                                    ani.beginTime = beginTime
                                }
                                ani.duration = aniDuration
                                layer.add(ani, forKey: "transform")
                                layer.transform = transform
                            }
                            if let opacity = to["opacity"] as? Float {
                                let ani = CABasicAnimation(keyPath: "opacity")
                                ani.fromValue = layer.opacity as NSValue
                                ani.toValue = opacity as NSValue
                                ani.fillMode = kCAFillModeBoth
                                if let beginTime = beginTime {
                                    ani.beginTime = beginTime
                                }
                                ani.duration = aniDuration
                                layer.add(ani, forKey: "transform")
                                layer.opacity = opacity
                            }
                        }
                    }
                }
            }
            CATransaction.commit()
        }
    }
    func pageIndex() -> Int? {
        return index
    }
    func pageCount() -> Int? {
        return pages.count
    }
}
