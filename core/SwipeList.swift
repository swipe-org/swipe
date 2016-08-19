//
//  SwipeList.swift
//
//  Created by Pete Stoppani on 5/26/16.
//

import Foundation
#if os(OSX)
    import Cocoa
#else
    import UIKit
#endif

class SwipeList: SwipeView, UITableViewDelegate, UITableViewDataSource {
    let TAG = "SWList"
    private var items = [[String:AnyObject]]()
    private var itemHeights = [CGFloat]()
    private var defaultItemHeight: CGFloat = 40
    private let scale:CGSize
    private var screenDimension = CGSize(width: 0, height: 0)
    weak var delegate:SwipeElementDelegate!
    var tableView: UITableView
    
    init(parent: SwipeNode, info: [String:AnyObject], scale: CGSize, frame: CGRect, screenDimension: CGSize, delegate:SwipeElementDelegate) {
        self.scale = scale
        self.screenDimension = screenDimension
        self.delegate = delegate
        self.tableView = UITableView(frame: frame, style: .Plain)
        super.init(parent: parent, info: info)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
#if !os(tvOS)
        self.tableView.separatorStyle = .None
#endif
        self.tableView.allowsSelection = true
        self.tableView.backgroundColor = UIColor.clearColor()
        
        if let value = info["itemH"] as? CGFloat {
            defaultItemHeight = value
        } else if let value = info["itemH"] as? String {
            defaultItemHeight = SwipeParser.parsePercent(value, full: screenDimension.height, defaultValue: defaultItemHeight)
        }

        if let itemsInfo = info["items"] as? [[String:AnyObject]] {
            items = itemsInfo
            for _ in items {
                itemHeights.append(defaultItemHeight)
            }
        }
        if let selectedIndex = self.info["selectedItem"] as? Int {
            self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: selectedIndex, inSection: 0), animated: true, scrollPosition: .Middle)
        }
        if let scrollEnabled = self.info["scrollEnabled"] as? Bool {
            self.tableView.scrollEnabled = scrollEnabled
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // UITableViewDataDelegate
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return itemHeights[indexPath.row]
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let actions = parent!.eventHandler.actionsFor("rowSelected") {
            parent!.execute(self, actions: actions)
        }
    }
    
    // UITableViewDataSource
    
    var cellIndexPath: NSIndexPath?
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let subviewTag = 999
        self.cellIndexPath = indexPath
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier("cell")! as UITableViewCell
        if let subView = cell.contentView.viewWithTag(subviewTag) {
            subView.removeFromSuperview()
        }
        var cellError: String?
        
        let item = self.items[indexPath.row]
        
        if let itemH = item["h"] as? CGFloat {
            self.itemHeights[indexPath.row] = itemH
        }
        let itemHeight = self.itemHeights[indexPath.row]
        
        if let elementsInfo = item["elements"] as? [[String:AnyObject]] {
            for elementInfo in elementsInfo {
                let element = SwipeElement(info: elementInfo, scale:self.scale, parent:self, delegate:self.delegate!)
                if let subview = element.loadViewInternal(CGSizeMake(self.tableView.bounds.size.width, itemHeight), screenDimension: self.screenDimension) {
                    subview.tag = subviewTag
                    cell.contentView.addSubview(subview)
                    children.append(element)
                } else {
                    cellError = "can't load"
                }
            }
        } else {
            cellError = "no elements"
        }
        
        if cellError != nil {
            let v = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.size.width, height: itemHeight))
            let l = UILabel(frame: CGRect(x:0, y:0, width: v.bounds.size.width, height: v.bounds.size.height))
            v.addSubview(l)
            cell.contentView.addSubview(v)
            l.text = "row \(indexPath.row) error " + cellError!
        }
        
        cell.selectionStyle = .None
        self.cellIndexPath = nil
        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    // SwipeView

    override func appendList(originator: SwipeNode, info: [String:AnyObject]) {
        if let itemsInfoArray = info["items"] as? [[String:AnyObject]] {
            var itemInfos = [[String:AnyObject]]()

            for itemInfo in itemsInfoArray {
                if let _ = itemInfo["data"] as? [String:AnyObject] {
                    var eval = originator.evaluate(itemInfo)
                    // if 'data' is a JSON string, use it, otherwise, use the info as is
                    if let dataStr = eval["data"] as? String, data = dataStr.dataUsingEncoding(NSUTF8StringEncoding) {
                        do {
                            guard let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String:AnyObject] else {
                                // 'data' is a plain String
                                itemInfos.append(eval)
                                break
                            }
                            
                            // 'data' is a JSON string so use the JSON object
                            if (json["elements"] as? [[String:AnyObject]]) != nil {
                                // 'data' is a redefinition of the item
                                itemInfos.append(json)
                            } else {
                                // 'data' is just data
                                eval["data"] = json
                                itemInfos.append(eval)
                            }
                        } catch  {
                            // 'data' is a plain String
                            itemInfos.append(eval)
                        }
                    } else {
                        // 'data' is a 'valueOf' JSON object
                        itemInfos.append(eval)                        
                    }
                } else {
                    itemInfos.append(itemInfo)
                }
            }
            
            var urls = [NSURL:String]()

            for itemInfo in itemInfos {
                if let elementsInfo = itemInfo["elements"] as? [[String:AnyObject]] {
                    let scaleDummy = CGSizeMake(0.1, 0.1)
                    
                    for e in elementsInfo {
                        let element = SwipeElement(info: e, scale:scaleDummy, parent:self, delegate:self.delegate!)
                        for (url, prefix) in element.resourceURLs {
                            urls[url] = prefix
                        }
                    }
                }
            }
            
            self.delegate.addedResourceURLs(urls) {
                for itemInfo in itemInfos {
                    self.items.append(itemInfo)
                    self.itemHeights.append(self.defaultItemHeight)
                }
                
                self.tableView.reloadData()
                self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: self.items.count - 1, inSection: 0), atScrollPosition: .Bottom, animated: true)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.4 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                    self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: self.items.count - 1, inSection: 0), atScrollPosition: .Bottom, animated: true)
                }
            }
        }
    }
    
    override func appendList(originator: SwipeNode, name: String, up: Bool, info: [String:AnyObject])  -> Bool {
        if (name == "*" || self.name.caseInsensitiveCompare(name) == .OrderedSame) {
            appendList(originator, info: info)
            return true
        }
        
        var node: SwipeNode? = self
        
        if up {
            while node?.parent != nil {
                if let viewNode = node?.parent as? SwipeView {
                    for c in viewNode.children {
                        if let e = c as? SwipeElement {
                            if e.name.caseInsensitiveCompare(name) == .OrderedSame {
                                e.appendList(originator, info: info)
                                return true
                            }
                        }
                    }
                    
                    node = node?.parent
                } else {
                    return false
                }
            }
        } else {
            for c in children {
                if let e = c as? SwipeElement {
                    if e.updateElement(originator, name:name, up:up, info:info) {
                        return true
                    }
                }
            }
        }
        
        return false
    }

    // SwipeNode
    
    override func getPropertyValue(originator: SwipeNode, property: String) -> AnyObject? {
        switch (property) {
        case "selectedItem":
            if let indexPath = self.tableView.indexPathForSelectedRow {
                return "\(indexPath.row)"
            } else {
                return "none"
            }
        default:
            return nil
        }
    }
    
    override func getPropertiesValue(originator: SwipeNode, info: [String:AnyObject]) -> AnyObject? {
        let prop = info.keys.first!
        switch (prop) {
        case "items":
            if let indexPath = self.cellIndexPath {
                var item = items[indexPath.row]
                if let itemStr = info["items"] as? String {
                    // ie "property":{"items":"data"}}
                    if let val = item[itemStr] as? String {
                        // ie "data":String
                        return val
                    } else if let valInfo = item[itemStr] as? [String:AnyObject] {
                        // ie "data":{...}
                        return originator.evaluate(valInfo)
                    }
                }
                // ie "property":{"items":{"data":{...}}}
                var path = info["items"] as! [String:AnyObject]
                var property = path.keys.first!
                
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
            } else {
                print("no cellIndexPath")
            }
            break;
        default:
            return nil
        }

        return nil
    }
}
