//
//  SwipeEventHandler.swift
//
//  Created by Pete Stoppani on 5/19/16.
//

import Foundation

class SwipeEventHandler: NSObject {
    
    private var events = [String:SwipeEvent]()
    
    func parse(eventsInfo: [String:AnyObject]) {
        for eventType in eventsInfo.keys {
            //NSLog("XdEventH parsed event: \(eventType)");
            if let eventInfo = eventsInfo[eventType] as? [String:AnyObject] {
                let event = SwipeEvent(type: eventType, info: eventInfo)
                events[eventType] = event
            }
        }
    }
    
    func actionsFor(event: String) -> [SwipeAction]? {
        return events[event]?.actions
    }
    
    func getEvent(event: String) -> SwipeEvent? {
        return events[event]
    }
}