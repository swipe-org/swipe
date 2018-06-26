//
//  SwipeTimer.swift
//
//  Created by Pete Stoppani on 5/23/16.
//

import Foundation

class SwipeTimer : SwipeNode {
    static var timers = [SwipeTimer]()
    var timer: Timer?
    var repeats = false
    
    static func create(_ parent: SwipeNode, timerInfo: [String:Any]) {
        let timer = SwipeTimer(parent: parent, timerInfo: timerInfo)
        timers.append(timer)
    }
    
    init(parent: SwipeNode, timerInfo: [String:Any]) {
        super.init(parent: parent)
        var duration = 0.2
        if let value = timerInfo["duration"] as? Double {
            duration = value
        }
        if let value = timerInfo["repeats"] as? Bool {
            repeats = value
        }
        if let eventsInfo = timerInfo["events"] as? [String:Any] {
            eventHandler.parse(eventsInfo)
            
            self.timer = Timer.scheduledTimer(timeInterval: duration, target:self, selector: #selector(SwipeTimer.didTimerTick(_:)), userInfo: nil, repeats: repeats)
        }
    }
    
    func cancel() {
        self.timer?.invalidate()
        self.timer = nil
    }

    static func cancelAll() {
        for timer in timers {
            timer.cancel()
        }
        
        timers.removeAll()
    }
    
    @objc func didTimerTick(_ timer: Timer) {
        if !timer.isValid {
            return
        }

        if let actions = eventHandler.actionsFor("tick") {
            execute(self, actions:actions)
        }
        
        if !repeats {
            cancel()
        }
    }
}
