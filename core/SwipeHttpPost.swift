//
//  SwipeHttpPost.swift
//
//  Created by Pete Stoppani on 6/16/16.
//

import Foundation

class SwipeHttpPost : SwipeNode {
    let TAG = "SWPost"
    private static var posters = [SwipeHttpPost]()
    private var params: [String:Any]?
    private var data: [String:Any]?
    
    static func create(_ parent: SwipeNode, postInfo: [String:Any]) {
        let poster = SwipeHttpPost(parent: parent, postInfo: postInfo)
        posters.append(poster)
    }
    
    init(parent: SwipeNode, postInfo: [String:Any]) {
        super.init(parent: parent)
        
        if let eventsInfo = postInfo["events"] as? [String:Any] {
            eventHandler.parse(eventsInfo)
        }
        
        if let targetInfo = postInfo["target"] as? [String:Any] {
            if var urlString = targetInfo["url"] as? String {
                if let params = postInfo["params"] as? [String:Any] {
                    var paramsSeparator = "?"
                    if urlString.contains("?") {
                        paramsSeparator = "&"
                    }
                    
                    for param in params.keys {
                        var val: String?

                        if let str = params[param] as? String {
                            val = str
                        } else if let valInfo = params[param] as? [String:Any],
                            let valOfInfo = valInfo["valueOf"] as? [String:Any],
                            let str = parent.getValue(parent, info:valOfInfo) as? String {
                            val = str
                        }
                        
                        if val != nil {
                            urlString.append(paramsSeparator)
                            urlString.append(param)
                            urlString.append("=")
                            urlString.append(val!.replacingOccurrences(of: "?", with: ""))
                            paramsSeparator = "&"
                        }
                    }
                }
                if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
                    let url = URL(string: encoded) {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"

                    if let dataStr = postInfo["data"] as? String {
                        request.httpBody = dataStr.data(using: .utf8)
                        request.setValue("text/plain; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                    }
                    if let data = postInfo["data"] as? [String:Any] {
                        let evalData = parent.evaluate(data)
                        do {
                            request.httpBody =  try JSONSerialization.data(withJSONObject: evalData, options: JSONSerialization.WritingOptions.prettyPrinted)
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
                    
                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
                        guard error == nil && data != nil else {                                                          // check for fundamental networking error
                            print("error=\(error)")
                            self.handleError("post error \(error)")
                            return
                        }
                        
                        if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                            print("statusCode should be 200, but is \(httpStatus.statusCode)")
                            print("response = \(response)")
                            self.handleError("post error \(httpStatus.statusCode)")
                            return
                        }
                        
                        let responseString = String(data: data!, encoding: .utf8)
                        print("responseString = \(responseString)")
                        
                        do {
                            guard let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()) as? [String:Any] else {
                                self.handleError("post \(urlString): not a dictionary.")
                                return
                            }
                            // Success
                            if let event = self.eventHandler.getEvent("completion"), let actionsInfo = self.eventHandler.actionsFor("completion") {
                                DispatchQueue.main.async {
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
    
    private func handleError(_ errorMsg: String) {
        if let event = self.eventHandler.getEvent("error"), let actionsInfo = self.eventHandler.actionsFor("error") {
            DispatchQueue.main.async {
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
                            let ret = sub[next]
                            if let str = ret as? String {
                                return str
                            } else if let arr = ret as? [Any] {
                                if arr.count > 0 {
                                    _ = "Array handling needs to be completed"
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
