//
//  SwipeEvent.swift
//
//  Created by Pete Stoppani on 5/19/16.
//

import Foundation

/* Format
 {
    "<event>": {
        "params": {"<p1>":{"type":"<type>"}, ... },
        "actions": [<action>, ... ]
 }
 */

class SwipeEvent: NSObject {
    private let info:[String:Any]
    let actions:[SwipeAction]
    private(set) lazy var params: [String:Any]? = {
        return self.info["params"] as? [String:Any]
    }()
    
    init(type: String, info: [String:Any]) {
        self.info = info
        if let paramsInfo = info["params"] as? [String:Any] {
            NSLog("XdEvent params: \(paramsInfo)")
        }
        let actionsInfo = info["actions"] as? [[String:Any]] ?? [[String:Any]]()
        actions = actionsInfo.map { SwipeAction(info: $0) }
    }
}
