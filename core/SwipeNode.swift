//
//  SwipeNode.swift
//
//  Created by Pete Stoppani on 5/19/16.
//

import Foundation

class SwipeNode: NSObject {
    var children = [SwipeNode]()
    private(set) weak var parent:SwipeNode?
    let eventHandler = SwipeEventHandler()

    init(parent: SwipeNode? = nil) {
        self.parent = parent
        super.init()
    }
    
    func evaluate(info:[String:AnyObject]) -> [String:AnyObject] {
        var result = [String:AnyObject]()
        
        for k in info.keys {
            var val = info[k]
            if let valInfo = val as? [String:AnyObject], valOfInfo = valInfo["valueOf"] as? [String:AnyObject] {
                val = getValue(self, info: valOfInfo)
                if val == nil {
                    val = ""
                }
            }
            
            result[k] = val
        }
        return result
    }
    
    func execute(originator: SwipeNode, actions:[SwipeAction]?) {
        if actions == nil {
            return
        }
        for action in actions! {
            executeAction(originator, action: action)
        }
    }
    
    func executeAction(originator: SwipeNode, action: SwipeAction) {
        if let getInfo = action.info["get"] as? [String:AnyObject] {
            SwipeHttpGet.create(self, getInfo: getInfo)
        } else if let postInfo = action.info["post"] as? [String:AnyObject] {
            SwipeHttpPost.create(self, postInfo: postInfo)
        } else {
            parent?.executeAction(originator, action: action)
        }
    }

    func getPropertyValue(originator: SwipeNode, property: String) -> AnyObject? {
        return self.parent?.getPropertyValue(originator, property: property)
    }
    
    func getPropertiesValue(originator: SwipeNode, info: [String:AnyObject]) -> AnyObject? {
        return self.parent?.getPropertiesValue(originator, info: info)
    }
    
    func getValue(originator: SwipeNode, info: [String:AnyObject]) -> AnyObject? {
        var up = true
        if let val = info["search"] as? String {
            up = val != "children"
        }
        
        if let property = info["property"] as? String {
            return getPropertyValue(originator, property: property)
        } else if let propertyInfo = info["property"] as? [String:AnyObject] {
            return getPropertiesValue(originator, info: propertyInfo)
        } else {
            if up {
                return self.parent?.getValue(originator, info: info)
            } else {
                for c in self.children {
                    let val = c.getValue(originator, info: info)
                    if val != nil {
                        return val
                    }
                }
            }
        }
        
        return nil
    }
}