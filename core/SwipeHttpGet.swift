//
//  SwipeHttpGet.swift
//
//  Created by Pete Stoppani on 6/9/16.
//

import Foundation

class SwipeHttpGet : SwipeNode {
    let TAG = "SwipeHttpGet"
    private static var getters = [SwipeHttpGet]()
    private var params: [String:Any]?
    private var data: [String:Any]?
    
    static func create(_ parent: SwipeNode, getInfo: [String:Any]) {
        let geter = SwipeHttpGet(parent: parent, getInfo: getInfo)
        getters.append(geter)
    }
    
    init(parent: SwipeNode, getInfo: [String:Any]) {
        super.init(parent: parent)

        if let eventsInfo = getInfo["events"] as? [String:Any] {
            eventHandler.parse(eventsInfo)
        }
        
        if let sourceInfo = getInfo["source"] as? [String:Any] {
            if let urlString = sourceInfo["url"] as? String, let url = URL(string: urlString) {
                SwipeAssetManager.sharedInstance().loadAsset(url, prefix: "", bypassCache:true) { (urlLocal:URL?, error:NSError?) -> Void in
                    if let urlL = urlLocal, error == nil, let data = try? Data(contentsOf: urlL) {
                        do {
                            guard let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? [String:Any] else {
                                self.handleError("get \(urlString): not a dictionary.")
                                return
                            }
                            // Success
                            if let event = self.eventHandler.getEvent("completion"), let actionsInfo = self.eventHandler.actionsFor("completion") {
                                self.data = json
                                self.params = event.params
                                self.execute(self, actions: actionsInfo)
                            }
                        } catch let error as NSError {
                            self.handleError("get \(urlString): invalid JSON file \(error.localizedDescription)")
                            return
                        }
                    } else {
                        self.handleError("get \(urlString): \(error?.localizedDescription ?? "")")
                    }
                }
            } else {
                self.handleError("get missing or invalid url")
            }
        } else {
            self.handleError("get missing source")
        }
    }
    
    private func handleError(_ errorMsg: String) {
        if let event = self.eventHandler.getEvent("error"), let actionsInfo = self.eventHandler.actionsFor("error") {
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
    
    override func getPropertiesValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
        let prop = info.keys.first!
        NSLog(TAG + " getPropsVal(\(prop))")
        
        switch (prop) {
        case "params":
            if let params = self.params, let data = self.data {
                NSLog(TAG + " not checking params \(params)")
                var item:[String:Any] = ["params":data]
                var path = info
                var property = "params"
                
                while (true) {
                    if let next = path[property] as? String {
                        if let sub = item[property] as? [String:Any] {
                            return sub[next]
                        } else {
                            return nil
                        }
                    } else if let next = path[property] as? [String:Any] {
                        if let sub = item[property] as? [String:Any] {
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
