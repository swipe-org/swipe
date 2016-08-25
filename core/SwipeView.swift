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
    func addedResourceURLs(urls:[NSURL:String], callback:() -> Void)
}

class SwipeView: SwipeNode {

    internal var info = [String:AnyObject]()
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
        
        override func canBecomeFocused() -> Bool {
            if let element = self.wrapper as? SwipeElement, _ = element.helper?.view {
                 return false
            } else if let wrapper = self.wrapper {
                return wrapper.fFocusable
            } else {
                return super.canBecomeFocused()
            }
        }
        
        override func didUpdateFocusInContext(context: UIFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {
            if let wrapper = self.wrapper {
                // lostFocus must be fired before gainedFocus
                if let actions = wrapper.eventHandler.actionsFor("lostFocus") where self == context.previouslyFocusedView  {
                    wrapper.execute(wrapper, actions: actions)
                }
                if let actions = wrapper.eventHandler.actionsFor("gainedFocus") where self == context.nextFocusedView  {
                    wrapper.execute(wrapper, actions: actions)
                }
            } else {
                super.didUpdateFocusInContext(context, withAnimationCoordinator: coordinator)
            }
        }
    }
    var view: UIView?
    
    init(info: [String:AnyObject]) {
        self.info = info
        super.init()
    }
    
    init(parent: SwipeNode, info: [String:AnyObject]) {
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
            tapRecognizer.requireGestureRecognizerToFail(doubleTapRecognizer!)
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
    
    lazy var data:AnyObject = {
        if let value = self.info["data"] as? String {
            return value
        } else if let value = self.info["data"] as? [String:AnyObject] {
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
    
    func setText(text:String, scale:CGSize, info:[String:AnyObject], dimension:CGSize, layer:CALayer?) -> Bool {
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
    
    func didTap(recognizer: UITapGestureRecognizer) {
        if let actions = eventHandler.actionsFor("tapped") where fEnabled {
            execute(self, actions: actions)
            completeTap()
        } else  if let p = self.parent as? SwipeView {
            p.didTap(recognizer)
            // parent will completeTap()
        } else {
            completeTap()
        }
    }
    
    func didDoubleTap(recognizer: UITapGestureRecognizer) {
        if let actions = eventHandler.actionsFor("doubleTapped") where fEnabled  {
            execute(self, actions: actions)
        }
    }
    
    override func executeAction(originator: SwipeNode, action: SwipeAction) {
        if let updateInfo = action.info["update"] as? [String:AnyObject] {
            var name = "*"; // default is 'self'
            if let value = updateInfo["id"] as? String {
                name = value
            }
            var up = true
            if let value = updateInfo["search"] as? String {
                up = value != "children"
            }
            updateElement(originator, name:name, up:up, info: updateInfo)
        } else if let appendInfo = action.info["append"] as? [String:AnyObject] {
            var name = "*"; // default is 'self'
            if let value = appendInfo["id"] as? String {
                name = value
            }
            var up = true
            if let value = appendInfo["search"] as? String {
                up = value != "children"
            }
            appendList(originator, name:name, up:up, info: appendInfo)
        } else  {
           super.executeAction(originator, action: action)
        }
    }
    
    func updateElement(originator: SwipeNode, name: String, up: Bool, info: [String:AnyObject])  -> Bool {
        return false
    }
    
    override func getPropertyValue(originator: SwipeNode, property: String) -> AnyObject? {
        switch (property) {
        case "data":
            return self.data
        case "screenX":
            return self.view!.superview?.convertPoint(self.view!.frame.origin, toView: nil).x
        case "screenY":
            return self.view!.superview?.convertPoint(self.view!.frame.origin, toView: nil).y
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
    func appendList(originator: SwipeNode, name: String, up: Bool, info: [String:AnyObject])  -> Bool {
        return false
    }
    
    func appendList(originator: SwipeNode, info: [String:AnyObject]) {
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