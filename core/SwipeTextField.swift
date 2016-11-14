//
//  SwipeTextField.swift
//
//  Created by Pete Stoppani on 8/24/16.
//

import Foundation

#if os(OSX)
    import Cocoa
#else
    import UIKit
#endif

class SwipeTextField: SwipeView, UITextFieldDelegate {
    private var screenDimension = CGSize(width: 0, height: 0)
    
    class InternalTextField: UITextField {
        weak var wrapper: SwipeTextField?
        
        init(wrapper: SwipeTextField?, frame: CGRect) {
            super.init(frame: frame)
            self.wrapper = wrapper
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var canBecomeFocused: Bool {
            if let wrapper = self.wrapper, let parent = wrapper.parent as? SwipeView {
                return parent.fFocusable
            } else {
                return super.canBecomeFocused
            }
        }
        
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            if let wrapper = self.wrapper, let parent = wrapper.parent as? SwipeView {
                // lostFocus must be fired before gainedFocus
                if self == context.previouslyFocusedView {
                    if let actions = parent.eventHandler.actionsFor("lostFocus")  {
                        parent.execute(parent, actions: actions)
                    }
                }
                if self == context.nextFocusedView {
                    if let actions = parent.eventHandler.actionsFor("gainedFocus") {
                        parent.execute(parent, actions: actions)
                    }
                }
            } else {
                super.didUpdateFocus(in: context, with: coordinator)
            }
        }
    }
    
    var textView: InternalTextField?
    
    init(parent: SwipeView, info: [String:Any], frame: CGRect, screenDimension: CGSize) {
        self.screenDimension = screenDimension
        super.init(parent: parent, info: info)
        self.textView = InternalTextField(wrapper: self, frame: frame)
        self.textView!.delegate = self
        self.textView!.backgroundColor = UIColor.clear
        self.view = self.textView! as UIView
    }
    
    override func setText(_ text:String, scale:CGSize, info:[String:Any], dimension:CGSize, layer:CALayer?) -> Bool {
        if let textView = self.textView {
            textView.text = text
            textView.textAlignment = NSTextAlignment.center
            
            func processAlignment(_ alignment:String) {
                switch(alignment) {
                case "center":
                    textView.textAlignment = .center
                case "left":
                    textView.textAlignment = .left
                case "right":
                    textView.textAlignment = .right
                case "justified":
                    textView.textAlignment = .justified
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
            
            textView.font = UIFont(name: "Helvetica", size: fontSize)
            textView.textColor = UIColor(cgColor: SwipeParser.parseColor(info["textColor"], defaultColor: UIColor.black.cgColor))
            
            parent!.execute(self, actions: parent!.eventHandler.actionsFor("textChanged"))
        }
        
        return true
    }
    
    override func getPropertyValue(_ originator: SwipeNode, property: String) -> Any? {
        switch (property) {
        case "text":
            return self.textView!.text
        case "text.length":
            return self.textView?.text?.characters.count
        default:
            return super.getPropertyValue(originator, property: property)
        }
    }
    
    override func isFirstResponder() -> Bool {
        return view!.isFirstResponder
    }
    
    // UITextViewDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            self.parent!.execute(self, actions: self.parent!.eventHandler.actionsFor("textChanged"))
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        parent!.execute(self, actions: parent!.eventHandler.actionsFor("endEdit"))
    }
}
