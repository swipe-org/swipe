//
//  SwipeHttpPost.swift
//
//  Created by Pete Stoppani on 6/16/16.
//

import Foundation

class SwipeHttpPost : SwipeNode {
    let TAG = "SWPost"
    private static var posters = [SwipeHttpPost]()
    private var params: [String:AnyObject]?
    private var data: [String:AnyObject]?
    
    static func create(parent: SwipeNode, postInfo: [String:AnyObject]) {
        let poster = SwipeHttpPost(parent: parent, postInfo: postInfo)
        posters.append(poster)
    }
    
    init(parent: SwipeNode, postInfo: [String:AnyObject]) {
        super.init(parent: parent)
        
        if let eventsInfo = postInfo["events"] as? [String:AnyObject] {
            eventHandler.parse(eventsInfo)
        }
        
        if let targetInfo = postInfo["target"] as? [String:AnyObject] {
            if var urlString = targetInfo["url"] as? String {
                if let params = postInfo["params"] as? [String:AnyObject] {
                    var paramsSeparator = "?"
                    if urlString.containsString("?") {
                        paramsSeparator = "&"
                    }
                    
                    for param in params.keys {
                        var val: String?

                        if let str = params[param] as? String {
                            val = str
                        } else if let valInfo = params[param] as? [String:AnyObject],
                            valOfInfo = valInfo["valueOf"] as? [String:AnyObject],
                            str = parent.getValue(parent, info:valOfInfo) as? String {
                            val = str
                        }
                        
                        if val != nil {
                            urlString.appendContentsOf(paramsSeparator)
                            urlString.appendContentsOf(param)
                            urlString.appendContentsOf("=")
                            urlString.appendContentsOf(val!.stringByReplacingOccurrencesOfString("?", withString: ""))
                            paramsSeparator = "&"
                        }
                    }
                }
                if let encoded = urlString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()),
                    url = NSURL(string: encoded) {
                    let request = NSMutableURLRequest(URL: url)
                    request.HTTPMethod = "POST"

                    if let dataStr = postInfo["data"] as? String {
                        request.HTTPBody = dataStr.dataUsingEncoding(NSUTF8StringEncoding)
                        request.setValue("text/plain; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                    }
                    if let data = postInfo["data"] as? [String:AnyObject] {
                        let evalData = parent.evaluate(data)
                        do {
                            request.HTTPBody =  try NSJSONSerialization.dataWithJSONObject(evalData, options: NSJSONWritingOptions.PrettyPrinted)
                            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                        } catch let error as NSError {
                            print("error=\(error)")
                            self.handleError("post error \(error)")
                            return
                        }
                    }
                    
                    if let headers = postInfo["headers"] as? [String:String] {
                        for h in headers.keys {
                            request.setValue(headers[h], forHTTPHeaderField: h)
                        }
                    }
                    
                    let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
                        guard error == nil && data != nil else {                                                          // check for fundamental networking error
                            print("error=\(error)")
                            self.handleError("post error \(error)")
                            return
                        }
                        
                        if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {           // check for http errors
                            print("statusCode should be 200, but is \(httpStatus.statusCode)")
                            print("response = \(response)")
                            self.handleError("post error \(httpStatus.statusCode)")
                            return
                        }
                        
                        let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
                        print("responseString = \(responseString)")
                        
                        do {
                            guard let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions()) as? [String:AnyObject] else {
                                self.handleError("post \(urlString): not a dictionary.")
                                return
                            }
                            // Success
                            if let event = self.eventHandler.getEvent("completion"), actionsInfo = self.eventHandler.actionsFor("completion") {
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.data = json
                                    self.params = event.params
                                    self.execute(self, actions: actionsInfo)
                                }
                            }
                        } catch let error as NSError {
                            self.handleError("post \(urlString): invalid JSON file \(error.localizedDescription)")
                            return
                        }
                    }
                    task.resume()
                } else {
                    self.handleError("post missing or invalid url")
                }
            } else {
                self.handleError("post missing or invalid url")
            }
        } else {
            self.handleError("post missing target")
        }
    }
    
    private func handleError(errorMsg: String) {
        if let event = self.eventHandler.getEvent("error"), actionsInfo = self.eventHandler.actionsFor("error") {
            dispatch_async(dispatch_get_main_queue()) {
                self.data = ["message":errorMsg]
                self.params = event.params
                self.execute(self, actions: actionsInfo)
            }
        } else {
            NSLog(TAG + errorMsg)
        }
    }
    
    func cancel() {
        
    }
    
    static func cancelAll() {
        posters.removeAll()
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
                            let ret = sub[next]
                            if let str = ret as? String {
                                return str
                            } else if let arr = ret as? [AnyObject] {
                                if arr.count > 0 {
                                    let warning = "Array handling needs to be completed"
                                    return arr[0]
                                } else {
                                    return nil
                                }
                            } else {
                                return ret
                            }
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