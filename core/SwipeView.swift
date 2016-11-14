//
//  SwipeView.swift
//
//  Created by Pete Stoppani on 5/19/16.
//

import Foundation
#if os(OSX)
    import Cocoa
    public typealias UIView = NSView
    public typealias UIButton = NSButton
    public typealias UIScreen = NSScreen
#else
    import UIKit
#endif

protocol SwipeViewDelegate: NSObjectProtocol {
    func addedResourceURLs(_ urls:[URL:String], callback:@escaping () -> Void)
}

class SwipeView: SwipeNode {

    internal var info = [String:Any]()
    internal var fEnabled = true
    internal var fFocusable = false

    class InternalView: UIView {
        weak var wrapper: SwipeView?
        
        init(wrapper: SwipeView?, frame: CGRect) {
            super.init(frame: frame)
            self.wrapper = wrapper
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var canBecomeFocused: Bool {
            if let element = self.wrapper as? SwipeElement, let _ = element.helper?.view {
                 return false
            } else if let wrapper = self.wrapper {
                return wrapper.fFocusable
            } else {
                return super.canBecomeFocused
            }
        }
        
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            if let wrapper = self.wrapper {
                // lostFocus must be fired before gainedFocus
                if let actions = wrapper.eventHandler.actionsFor("lostFocus"), self == context.previouslyFocusedView  {
                    wrapper.execute(wrapper, actions: actions)
                }
                if let actions = wrapper.eventHandler.actionsFor("gainedFocus"), self == context.nextFocusedView  {
                    wrapper.execute(wrapper, actions: actions)
                }
            } else {
                super.didUpdateFocus(in: context, with: coordinator)
            }
        }
    }
    var view: UIView?
    
    init(info: [String:Any]) {
        self.info = info
        super.init()
    }
    
    init(parent: SwipeNode, info: [String:Any]) {
        self.info = info
        super.init(parent: parent)
    }
    
    func setupGestureRecognizers() {
        var doubleTapRecognizer: UITapGestureRecognizer?
        
        if eventHandler.actionsFor("doubleTapped") != nil {
            doubleTapRecognizer = UITapGestureRecognizer(target: self, action:#selector(SwipeView.didDoubleTap(_:)))
            doubleTapRecognizer!.numberOfTapsRequired = 2
            doubleTapRecognizer!.cancelsTouchesInView = false
            view!.addGestureRecognizer(doubleTapRecognizer!)
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action:#selector(SwipeView.didTap(_:)))
        if doubleTapRecognizer != nil {
            tapRecognizer.require(toFail: doubleTapRecognizer!)
        }
        tapRecognizer.cancelsTouchesInView = false
        view!.addGestureRecognizer(tapRecognizer)
    }
    
    lazy var name:String = {
        if let value = self.info["id"] as? String {
            return value
        }
        return "" // default
    }()
    
    lazy var data:Any = {
        if let value = self.info["data"] as? String {
            return value
        } else if let value = self.info["data"] as? [String:Any] {
            return value
        }
        return "" // default
    }()
    
    func endEditing() {
        if let view = self.view {
            let ended = view.endEditing(true)
        if !ended {
            if let p = self.parent as? SwipeView {
                p.endEditing()
            }
        }
        }
    }
    
    func setText(_ text:String, scale:CGSize, info:[String:Any], dimension:CGSize, layer:CALayer?) -> Bool {
        return false
    }
    
    func tapped() {
        if let p = self.parent as? SwipeView {
            p.tapped()
        }
    }
    
    private func completeTap() {
        endEditing()
        tapped()
    }
    
    func didTap(_ recognizer: UITapGestureRecognizer) {
        if let actions = eventHandler.actionsFor("tapped"), fEnabled {
            execute(self, actions: actions)
            completeTap()
        } else  if let p = self.parent as? SwipeView {
            p.didTap(recognizer)
            // parent will completeTap()
        } else {
            completeTap()
        }
    }
    
    func didDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if let actions = eventHandler.actionsFor("doubleTapped"), fEnabled  {
            execute(self, actions: actions)
        }
    }
    
    override func executeAction(_ originator: SwipeNode, action: SwipeAction) {
        if let updateInfo = action.info["update"] as? [String:Any] {
            var name = "*"; // default is 'self'
            if let value = updateInfo["id"] as? String {
                name = value
            }
            var up = true
            if let value = updateInfo["search"] as? String {
                up = value != "children"
            }
            _ = updateElement(originator, name:name, up:up, info: updateInfo)
        } else if let appendInfo = action.info["append"] as? [String:Any] {
            var name = "*"; // default is 'self'
            if let value = appendInfo["id"] as? String {
                name = value
            }
            var up = true
            if let value = appendInfo["search"] as? String {
                up = value != "children"
            }
            _ = appendList(originator, name:name, up:up, info: appendInfo)
        } else  {
           super.executeAction(originator, action: action)
        }
    }
    
    func updateElement(_ originator: SwipeNode, name: String, up: Bool, info: [String:Any])  -> Bool {
        return false
    }
    
    override func getPropertyValue(_ originator: SwipeNode, property: String) -> Any? {
        switch (property) {
        case "data":
            return self.data
        case "screenX":
            return self.view!.superview?.convert(self.view!.frame.origin, to: nil).x
        case "screenY":
            return self.view!.superview?.convert(self.view!.frame.origin, to: nil).y
        case "x":
            return self.view!.frame.origin.x
        case "y":
            return self.view!.frame.origin.y
        case "w":
            return self.view!.frame.size.width
        case "h":
            return self.view!.frame.size.height
        default:
            return nil
        }
    }
    func appendList(_ originator: SwipeNode, name: String, up: Bool, info: [String:Any])  -> Bool {
        return false
    }
    
    func appendList(_ originator: SwipeNode, info: [String:Any]) {
    }
    
    func isFirstResponder() -> Bool {
        return false
    }
    
    func findFirstResponder() -> SwipeView? {
        if self.isFirstResponder() {
            return self
        }
        
        for c in self.children {
            if let e = c as? SwipeElement {
            if let fr = e.findFirstResponder() {
                return fr
            }
            }
        }
        
        return nil;
    }

}
