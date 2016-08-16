//
//  SwipeNode.swift
//
//  Created by Pete Stoppani on 5/19/16.
//

import Foundation

class SwipeNode: NSObject {
    var children = [SwipeNode]()
    weak var parent:SwipeNode?
    let eventHandler = SwipeEventHandler()
    var session: NSURLSession?

    override init() {
        self.parent = nil
        super.init()
    }
    
    init(parent: SwipeNode) {
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