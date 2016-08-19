//
//  SwipeHttpGet.swift
//
//  Created by Pete Stoppani on 6/9/16.
//

import Foundation

class SwipeHttpGet : SwipeNode {
    let TAG = "SwipeHttpGet"
    private static var getters = [SwipeHttpGet]()
    private var params: [String:AnyObject]?
    private var data: [String:AnyObject]?
    
    static func create(parent: SwipeNode, getInfo: [String:AnyObject]) {
        let geter = SwipeHttpGet(parent: parent, getInfo: getInfo)
        getters.append(geter)
    }
    
    init(parent: SwipeNode, getInfo: [String:AnyObject]) {
        super.init(parent: parent)

        if let eventsInfo = getInfo["events"] as? [String:AnyObject] {
            eventHandler.parse(eventsInfo)
        }
        
        if let sourceInfo = getInfo["source"] as? [String:AnyObject] {
            if let urlString = sourceInfo["url"] as? String, url = NSURL(string: urlString) {
                SwipeAssetManager.sharedInstance().loadAsset(url, prefix: "", bypassCache:true) { (urlLocal:NSURL?,  error:NSError!) -> Void in
                    if let urlL = urlLocal where error == nil, let data = NSData(contentsOfURL: urlL) {
                        do {
                            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String:AnyObject] else {
                                self.handleError("get \(urlString): not a dictionary.")
                                return
                            }
                            // Success
                            if let event = self.eventHandler.getEvent("completion"), actionsInfo = self.eventHandler.actionsFor("completion") {
                                self.data = json
                                self.params = event.params
                                self.execute(self, actions: actionsInfo)
                            }
                        } catch let error as NSError {
                            self.handleError("get \(urlString): invalid JSON file \(error.localizedDescription)")
                            return
                        }
                    } else {
                        self.handleError("get \(urlString): \(error.localizedDescription)")
                    }
                }
            } else {
                self.handleError("get missing or invalid url")
            }
        } else {
            self.handleError("get missing source")
        }
    }
    
    private func handleError(errorMsg: String) {
        if let event = self.eventHandler.getEvent("error"), actionsInfo = self.eventHandler.actionsFor("error") {
            self.data = ["message":errorMsg]
            self.params = event.params
            self.execute(self, actions: actionsInfo)
        } else {
            NSLog(TAG + errorMsg)
        }
    }
    
    func cancel() {

    }
    
    static func cancelAll() {
        for timer in getters {
            timer.cancel()
        }
        
        getters.removeAll()
    }
    
    // SwipeNode
    
    override func getPropertiesValue(originator: SwipeNode, info: [String:AnyObject]) -> AnyObject? {
        let prop = info.keys.first!
        NSLog(TAG + " getPropsVal(\(prop))")
        
        switch (prop) {
        case "params":
            if let params = self.params, data = self.data {
                NSLog(TAG + " not checking params \(params)")
                var item:[String:AnyObject] = ["params":data]
                var path = info
                var property = "params"
                
                while (true) {
                    if let next = path[property] as? String {
                        if let sub = item[property] as? [String:AnyObject] {
                            return sub[next]
                        } else {
                            return nil
                        }
                    } else if let next = path[property] as? [String:AnyObject] {
                        if let sub = item[property] as? [String:AnyObject] {
                            path = next
                            property = path.keys.first!
                            item = sub
                        } else {
                            return nil
                        }
                    } else {
                        return nil
                    }
                }
                
                // loop on properties in info until get to a String
            }
            break;
        default:
            return nil
        }
        
        return nil
    }

}