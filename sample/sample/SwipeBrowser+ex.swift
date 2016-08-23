//
//  SwipeBrowser+ex.swift
//  sample
//
//  Created by satoshi on 8/23/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

extension SwipeBrowser {
    @IBAction func export() {
        exportAsMovie()
    }

    func exportAsGifAnimation() {
        guard let swipeVC = controller as? SwipeViewController else {
            return
        }
        let docURL = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let fileURL = docURL.URLByAppendingPathComponent("ani.mov")
        
        self.viewLoading?.alpha = 1.0
        self.labelLoading?.text = "Exporting as a GIF animation...".localized
        let exporter = SwipeExporter(swipeViewController: swipeVC, fps:4)
        exporter.exportAsGifAnimation(fileURL, startPage: swipeVC.book.pageIndex, pageCount: 3) { (complete, error) -> Void in
            self.progress?.progress = Float(exporter.progress)
            if complete {
                print("GIF animation export done")
                UIView.animateWithDuration(0.2, animations: { () -> Void in
                    self.viewLoading?.alpha = 0.0
                }, completion: { (_:Bool) -> Void in
                    let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = self.btnExport
                    self.presentViewController(activity, animated: true, completion: nil)
                })
            } else if let error = error {
                self.viewLoading?.alpha = 0.0
                print("Error", error)
            } else {
                print("progress", exporter.progress)
            }
        }
    }
    
    func exportAsMovie() {
        guard let swipeVC = controller as? SwipeViewController else {
            return
        }
        let docURL = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let fileURL = docURL.URLByAppendingPathComponent("ani.mov")
        
        self.viewLoading?.alpha = 1.0
        self.labelLoading?.text = "Exporting as a movie...".localized
        let exporter = SwipeExporter(swipeViewController: swipeVC, fps:12, resolution:480.0)
        exporter.exportAsMovie(fileURL, startPage: swipeVC.book.pageIndex, pageCount: 3) { (complete, error) -> Void in
            self.progress?.progress = Float(exporter.progress)
            if complete {
                print("Movie export done", exporter.outputSize)
                UIView.animateWithDuration(0.2, animations: { () -> Void in
                    self.viewLoading?.alpha = 0.0
                }, completion: { (_:Bool) -> Void in
                    let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = self.btnExport
                    self.presentViewController(activity, animated: true, completion: nil)
                })
            } else if let error = error {
                self.viewLoading?.alpha = 0.0
                print("Error", error)
            } else {
                print("progress", exporter.progress)
            }
        }
    }
}
