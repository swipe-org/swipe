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
import AVFoundation

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

    func exportAsMovie(fileURL:NSURL, startPage:Int, pageCount:Int, progress:(complete:Bool, error:ErrorType?)->Void) {
        let manager = NSFileManager.defaultManager()
        if manager.fileExistsAtPath(fileURL.path!) {
            try! manager.removeItemAtURL(fileURL)
        }
        do {
            let writer = try AVAssetWriter(URL: fileURL, fileType: AVFileTypeQuickTimeMovie)
            let input = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: [
                AVVideoCodecKey : AVVideoCodecH264,
                AVVideoWidthKey : 320.0,
                AVVideoHeightKey : 480.0
            ])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(unsignedInt: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: 320.0,
                kCVPixelBufferHeightKey as String: 480.0,
            ])
            iFrame = 0
            writer.addInput(input)
            guard writer.startWriting() else {
                return progress(complete: false, error: Error.FailedToFinalize)
            }
            writer.startSessionAtSourceTime(kCMTimeZero)
            
            let frameDuration = CMTimeMake(1, Int32(self.fps))
            
            input.requestMediaDataWhenReadyOnQueue(dispatch_get_main_queue()) {
                print("ready", self.iFrame)
                guard input.readyForMoreMediaData else {
                    return
                }
                print("ready 2", self.iFrame)
                self.progress = CGFloat(self.iFrame) / CGFloat(self.fps) / CGFloat(pageCount)
                self.swipeViewController.scrollTo(CGFloat(startPage) + CGFloat(self.iFrame) / CGFloat(self.fps))

                let presentationLayer = self.swipeViewController.view.layer.presentationLayer() as! CALayer
                UIGraphicsBeginImageContext(self.swipeViewController.view.frame.size); defer {
                    UIGraphicsEndImageContext()
                }
                presentationLayer.renderInContext(UIGraphicsGetCurrentContext()!)
                let image = UIGraphicsGetImageFromCurrentImageContext()!

                let lastFrameTime = CMTimeMake(Int64(self.iFrame), Int32(self.fps))
                let presentationTime = self.iFrame == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)

                var pixelBufferX: CVPixelBuffer? = nil
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &pixelBufferX)
                
                guard let managedPixelBuffer = pixelBufferX where status == 0  else {
                    print("failed to allocate pixel buffer")
                    return
                }

                CVPixelBufferLockBaseAddress(managedPixelBuffer, 0)

                let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                let context = CGBitmapContextCreate(data, Int(320), Int(480), 8, CVPixelBufferGetBytesPerRow(managedPixelBuffer), rgbColorSpace, CGImageAlphaInfo.PremultipliedFirst.rawValue)

                CGContextClearRect(context, CGRectMake(0, 0, CGFloat(320), CGFloat(480)))

                let horizontalRatio = CGFloat(320) / image.size.width
                let verticalRatio = CGFloat(480) / image.size.height
                //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
                let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit

                let newSize:CGSize = CGSizeMake(image.size.width * aspectRatio, image.size.height * aspectRatio)

                let x = newSize.width < 320 ? (320 - newSize.width) / 2 : 0
                let y = newSize.height < 480 ? (480 - newSize.height) / 2 : 0

                CGContextDrawImage(context, CGRectMake(x, y, newSize.width, newSize.height), image.CGImage)

                CVPixelBufferUnlockBaseAddress(managedPixelBuffer, 0)

                if !adaptor.appendPixelBuffer(managedPixelBuffer, withPresentationTime: presentationTime) {
                    print("failed to append")
                    return
                }

                self.iFrame += 1
                if self.iFrame < pageCount * self.fps + 1 {
                    // loop
                } else {
                    input.markAsFinished()
                    writer.finishWritingWithCompletionHandler({
                        print("finished")
                        progress(complete: true, error: nil)
                    })
                }
            }
        } catch let error {
            progress(complete: false, error: error)
        }
    }
    

}
