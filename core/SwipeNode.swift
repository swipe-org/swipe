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
    
    func evaluate(_ info:[String:Any]) -> [String:Any] {
        var result = [String:Any]()
        
        for k in info.keys {
            var val = info[k]
            if let valInfo = val as? [String:Any], let valOfInfo = valInfo["valueOf"] as? [String:Any] {
                val = getValue(self, info: valOfInfo)
                if val == nil {
                    val = ""
                }
            }
            
            result[k] = val
        }
        return result
    }
    
    func execute(_ originator: SwipeNode, actions:[SwipeAction]?) {
        if actions == nil {
            return
        }
        for action in actions! {
            executeAction(originator, action: action)
        }
    }
    
    func executeAction(_ originator: SwipeNode, action: SwipeAction) {
        if let getInfo = action.info["get"] as? [String:Any] {
            SwipeHttpGet.create(self, getInfo: getInfo)
        } else if let postInfo = action.info["post"] as? [String:Any] {
            SwipeHttpPost.create(self, postInfo: postInfo)
        } else if let timerInfo = action.info["timer"] as? [String:Any] {
            SwipeTimer.create(self, timerInfo: timerInfo)
        } else {
            parent?.executeAction(originator, action: action)
        }
    }

    func getPropertyValue(_ originator: SwipeNode, property: String) -> Any? {
        return self.parent?.getPropertyValue(originator, property: property)
    }
    
    func getPropertiesValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
        return self.parent?.getPropertiesValue(originator, info: info)
    }
    
    func getValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
        var up = true
        if let val = info["search"] as? String {
            up = val != "children"
        }
        
        if let property = info["property"] as? String {
            return getPropertyValue(originator, property: property)
        } else if let propertyInfo = info["property"] as? [String:Any] {
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
