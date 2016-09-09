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
    enum Error: Swift.Error {
        case FailedToCreate
        case FailedToFinalize
    }

    let swipeViewController:SwipeViewController
    let fps:Int
    let resolution:CGFloat
    var progress = 0.0 as CGFloat // Output: Proress from 0.0 to 1.0
    var outputSize = CGSize.zero    // Output: Size of generated GIF/video
    
    private var iFrame = 0
    
    init(swipeViewController:SwipeViewController, fps:Int, resolution:CGFloat = 720.0) {
        self.swipeViewController = swipeViewController
        self.fps = fps
        self.resolution = resolution
    }
    
    func exportAsGifAnimation(_ fileURL:URL, startPage:Int, pageCount:Int, progress:(complete:Bool, error:Swift.Error?)->Void) {
        guard let idst = CGImageDestinationCreateWithURL(fileURL, kUTTypeGIF, pageCount * fps + 1, nil) else {
            return progress(complete: false, error: Error.FailedToCreate)
        }
        CGImageDestinationSetProperties(idst, [String(kCGImagePropertyGIFDictionary):
                                 [String(kCGImagePropertyGIFLoopCount):0]])
        iFrame = 0
        outputSize = swipeViewController.view.frame.size
        self.processFrame(idst, startPage:startPage, pageCount: pageCount, progress:progress)
    }

    func processFrame(_ idst:CGImageDestination, startPage:Int, pageCount:Int, progress:(complete:Bool, error:Swift.Error?)->Void) {
        self.progress = CGFloat(iFrame) / CGFloat(fps) / CGFloat(pageCount)
        swipeViewController.scrollTo(CGFloat(startPage) + CGFloat(iFrame) / CGFloat(fps))
        
        // HACK: This delay is not 100% reliable, but is sufficient practically.
        DispatchQueue.main.asyncAfter(deadline: .now() + 100) {
            progress(complete: false, error: nil)
            let presentationLayer = self.swipeViewController.view.layer.presentation()!
            UIGraphicsBeginImageContext(self.swipeViewController.view.frame.size); defer {
                UIGraphicsEndImageContext()
            }
            presentationLayer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()!

            CGImageDestinationAddImage(idst, image.cgImage!, [String(kCGImagePropertyGIFDictionary):
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

    func exportAsMovie(_ fileURL:URL, startPage:Int, pageCount:Int, progress:(complete:Bool, error:Swift.Error?)->Void) {
        // AVAssetWrite will fail if the file already exists
        let manager = FileManager.default
        if manager.fileExists(atPath: fileURL.path) {
            try! manager.removeItem(at: fileURL)
        }
        
        let viewSize = swipeViewController.view.frame.size
        let scale = min(resolution / min(viewSize.width, viewSize.height), swipeViewController.view.contentScaleFactor)
        
        outputSize = CGSize(width: viewSize.width * scale, height: viewSize.height * scale)

        do {
            let writer = try AVAssetWriter(url: fileURL, fileType: AVFileTypeQuickTimeMovie)
            let input = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: [
                AVVideoCodecKey : AVVideoCodecH264,
                AVVideoWidthKey : outputSize.width,
                AVVideoHeightKey : outputSize.height
            ])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: outputSize.width,
                kCVPixelBufferHeightKey as String: outputSize.height,
            ])
            writer.add(input)
            
            iFrame = 0

            guard writer.startWriting() else {
                return progress(complete: false, error: Error.FailedToFinalize)
            }
            writer.startSession(atSourceTime: kCMTimeZero)
            
            self.swipeViewController.scrollTo(CGFloat(startPage))
            input.requestMediaDataWhenReady(on: DispatchQueue.main) {
                guard input.isReadyForMoreMediaData else {
                    return // Not ready. Just wait.
                }
                self.progress = 0.5 * CGFloat(self.iFrame) / CGFloat(self.fps) / CGFloat(pageCount)
                progress(complete: false, error: nil)

                var pixelBufferX: CVPixelBuffer? = nil
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &pixelBufferX)
                guard let managedPixelBuffer = pixelBufferX, status == 0  else {
                    print("failed to allocate pixel buffer")
                    writer.cancelWriting()
                    return progress(complete: false, error: Error.FailedToCreate)
                }

                CVPixelBufferLockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                if let context = CGContext(data: data, width: Int(self.outputSize.width), height: Int(self.outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
                    let xf = CGAffineTransform(scaleX: scale, y: -scale)
                    context.concatenate(xf.translatedBy(x: 0, y: -viewSize.height))
                    let presentationLayer = self.swipeViewController.view.layer.presentation()!
                    presentationLayer.render(in: context)
                }
                CVPixelBufferUnlockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))

                let presentationTime = CMTimeMake(Int64(self.iFrame), Int32(self.fps))
                if !adaptor.append(managedPixelBuffer, withPresentationTime: presentationTime) {
                    writer.cancelWriting()
                    return progress(complete: false, error: Error.FailedToCreate)
                }

                self.iFrame += 1
                if self.iFrame < pageCount * self.fps + 1 {
                    self.swipeViewController.scrollTo(CGFloat(startPage) + CGFloat(self.iFrame) / CGFloat(self.fps))
                } else {
                    input.markAsFinished()
                    print("SwipeExporter: finishWritingWithCompletionHandler")
                    writer.finishWritingWithCompletionHandler({
                        dispatch_async(dispatch_get_main_queue()) {
                            progress(complete: true, error: nil)
                        }
                    })
                }
            }
        } catch let error {
            progress(complete: false, error: error)
        }
    }
}
