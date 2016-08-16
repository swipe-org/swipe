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
    
    func execute(originator: SwipeNode, actions:[SwipeAction]?) {
        if actions == nil {
            return
        }
        for action in actions! {
            executeAction(originator, action: action)
        }
    }
    
    func executeAction(originator: SwipeNode, action: SwipeAction) {
        parent?.executeAction(originator, action: action)
    }
 }