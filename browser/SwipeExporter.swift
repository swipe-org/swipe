//
//  SwipeExporter.swift
//  sample
//
//  Created by satoshi on 8/19/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices

class SwipeExporter: NSObject {
    enum Error:ErrorType {
        case FailedToCreate
        case FailedToFinalize
    }

    let swipeViewController:SwipeViewController
    let fps:Int
    var progress = 0.0 as CGFloat
    private var iFrame = 0
    
    init(swipeViewController:SwipeViewController, fps:Int) {
        self.swipeViewController = swipeViewController
        self.fps = fps
    }
    
    func exportAsGifAnimation(fileURL:NSURL, startPage:Int, pageCount:Int, progress:(complete:Bool, error:ErrorType?)->Void) {
        guard let idst = CGImageDestinationCreateWithURL(fileURL, kUTTypeGIF, pageCount * fps + 1, nil) else {
            return progress(complete: false, error: Error.FailedToCreate)
        }
        CGImageDestinationSetProperties(idst, [String(kCGImagePropertyGIFDictionary):
                                 [String(kCGImagePropertyGIFLoopCount):0]])
        iFrame = 0
        self.processFrame(idst, startPage:startPage, pageCount: pageCount, progress:progress)
    }

    func processFrame(idst:CGImageDestination, startPage:Int, pageCount:Int, progress:(complete:Bool, error: ErrorType?)->Void) {
        self.progress = CGFloat(iFrame) / CGFloat(fps) / CGFloat(pageCount)
        swipeViewController.scrollTo(CGFloat(startPage) + CGFloat(iFrame) / CGFloat(fps))
        
        // HACK: This delay is not 100% reliable, but is sufficient practically.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(100 * Double(NSEC_PER_MSEC))), dispatch_get_main_queue()) {
            progress(complete: false, error: nil)
            let presentationLayer = self.swipeViewController.view.layer.presentationLayer() as! CALayer
            UIGraphicsBeginImageContext(self.swipeViewController.view.frame.size); defer {
                UIGraphicsEndImageContext()
            }
            presentationLayer.renderInContext(UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()!

            CGImageDestinationAddImage(idst, image.CGImage!, [String(kCGImagePropertyGIFDictionary):
                             [String(kCGImagePropertyGIFDelayTime):0.2]])
            
            self.iFrame += 1
            if self.iFrame < pageCount * self.fps + 1 {
                self.processFrame(idst, startPage:startPage, pageCount: pageCount, progress:progress)
            } else {
                if CGImageDestinationFinalize(idst) {
                    progress(complete: true, error: nil)
                } else {
                    progress(complete: false, error: Error.FailedToFinalize)
                }
            }
        }
    }
}
