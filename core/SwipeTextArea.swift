//
//  SwipeTextArea.swift
//
//  Created by Pete Stoppani on 6/7/16.
//

import Foundation

#if os(OSX)
    import Cocoa
#else
    import UIKit
#endif

class SwipeTextArea: SwipeView, UITextViewDelegate {
    private var screenDimension = CGSize(width: 0, height: 0)
    private var textView: UITextView

    init(parent: SwipeNode, info: [String:Any], frame: CGRect, screenDimension: CGSize) {
        self.screenDimension = screenDimension
        self.textView = UITextView(frame: frame)
        super.init(parent: parent, info: info)
        self.textView.delegate = self
        self.textView.backgroundColor = UIColor.clear
        //self.textView.becomeFirstResponder()
        self.view = self.textView as UIView
    }
    
    override func setText(_ text:String, scale:CGSize, info:[String:Any], dimension:CGSize, layer:CALayer?) -> Bool {
        self.textView.text = text
        self.textView.textAlignment = NSTextAlignment.center
        
        func processAlignment(_ alignment:String) {
            switch(alignment) {
            case "center":
                self.textView.textAlignment = .center
            case "left":
                self.textView.textAlignment = .left
            case "right":
                self.textView.textAlignment = .right
            case "justified":
                self.textView.textAlignment = .justified
            default:
                break
            }
        }
        if let alignment = info["textAlign"] as? String {
            processAlignment(alignment)
        } else if let alignments = info["textAlign"] as? [String] {
            for alignment in alignments {
                processAlignment(alignment)
            }
        }
        let fontSize:CGFloat = {
            var ret = 20.0 / 480.0 * dimension.height // default
            if let fontSize = info["fontSize"] as? CGFloat {
                ret = fontSize
            } else if let fontSize = info["fontSize"] as? String {
                ret = SwipeParser.parsePercent(fontSize, full: dimension.height, defaultValue: ret)
            }
            return round(ret * scale.height)
        }()
        
        self.textView.font = UIFont(name: "Helvetica", size: fontSize)
        self.textView.textColor = UIColor(cgColor: SwipeParser.parseColor(info["textColor"], defaultColor: UIColor.black.cgColor))
        
        parent!.execute(self, actions: parent!.eventHandler.actionsFor("textChanged"))

        return true
    }
    
    override func getPropertyValue(_ originator: SwipeNode, property: String) -> Any? {
        switch (property) {
        case "text":
            return self.textView.text
        case "text.length":
            return self.textView.text?.characters.count
        default:
            return super.getPropertyValue(originator, property: property)
        }
    }

    override func isFirstResponder() -> Bool {
        return view!.isFirstResponder
    }

    // UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        parent!.execute(self, actions: parent!.eventHandler.actionsFor("textChanged"))
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        parent!.execute(self, actions: parent!.eventHandler.actionsFor("endEdit"))
    }
}
