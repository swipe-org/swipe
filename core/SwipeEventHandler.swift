//
//  SwipeEventHandler.swift
//
//  Created by Pete Stoppani on 5/19/16.
//

import Foundation

class SwipeEventHandler: NSObject {
    static var count = 0

    private var events = [String:SwipeEvent]()

    override init () {
        super.init()
        SwipeEventHandler.count += 1
        //print("SEventHandler init", SwipeEventHandler.count)
    }
    
    deinit {
        SwipeEventHandler.count -= 1
        //print("SEventHandler deinit", SwipeEventHandler.count)
    }

    func parse(_ eventsInfo: [String:Any]) {
        for eventType in eventsInfo.keys {
            //NSLog("XdEventH parsed event: \(eventType)");
            if let eventInfo = eventsInfo[eventType] as? [String:Any] {
                let event = SwipeEvent(type: eventType, info: eventInfo)
                events[eventType] = event
            }
        }
    }
    
    func actionsFor(_ event: String) -> [SwipeAction]? {
        return events[event]?.actions
    }
    
    func getEvent(_ event: String) -> SwipeEvent? {
        return events[event]
    }
}
