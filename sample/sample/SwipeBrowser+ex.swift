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
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.popoverPresentationController?.sourceView = btnExport
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Movie".localized, style: .default) {
            (_:UIAlertAction) -> Void in
            self.exportAsMovie()
            })
        alert.addAction(UIAlertAction(title: "GIF Animation".localized, style: .default) {
            (_:UIAlertAction) -> Void in
            self.exportAsGifAnimation()
            })
        self.present(alert, animated: true, completion: nil)
    }

    func exportAsGifAnimation() {
        guard let swipeVC = controller as? SwipeViewController else {
            return
        }
        let docURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = docURL.appendingPathComponent("swipe.gif")
        
        self.viewLoading?.alpha = 1.0
        self.labelLoading?.text = "Exporting as a GIF animation...".localized
        let exporter = SwipeExporter(swipeViewController: swipeVC, fps:4)
        exporter.exportAsGifAnimation(fileURL, startPage: swipeVC.book.pageIndex, pageCount: 3) { (complete, error) -> Void in
            self.progress?.progress = Float(exporter.progress)
            if complete {
                print("GIF animation export done")
                UIView.animate(withDuration: 0.2, animations: { () -> Void in
                    self.viewLoading?.alpha = 0.0
                }, completion: { (_:Bool) -> Void in
                    let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = self.btnExport
                    self.present(activity, animated: true, completion: nil)
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
        let docURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = docURL.appendingPathComponent("swipe.mov")
        
        self.viewLoading?.alpha = 1.0
        self.labelLoading?.text = "Exporting as a movie...".localized
        let exporter = SwipeExporter(swipeViewController: swipeVC, fps:30, resolution:720.0)
        exporter.exportAsMovie(fileURL, startPage: swipeVC.book.pageIndex, pageCount: nil) { (complete, error) -> Void in
            self.progress?.progress = Float(exporter.progress)
            if complete {
                print("Movie export done", exporter.outputSize)
                UIView.animate(withDuration: 0.2, animations: { () -> Void in
                    self.viewLoading?.alpha = 0.0
                }, completion: { (_:Bool) -> Void in
                    let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = self.btnExport
                    self.present(activity, animated: true, completion: nil)
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
