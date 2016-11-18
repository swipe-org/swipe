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
    private var items = [[String:Any]]()
    private var itemHeights = [CGFloat]()
    private var defaultItemHeight: CGFloat = 40
    private let scale:CGSize
    private var screenDimension = CGSize(width: 0, height: 0)
    weak var delegate:SwipeElementDelegate!
    var tableView: UITableView
    
    init(parent: SwipeNode, info: [String:Any], scale: CGSize, frame: CGRect, screenDimension: CGSize, delegate:SwipeElementDelegate) {
        self.scale = scale
        self.screenDimension = screenDimension
        self.delegate = delegate
        self.tableView = UITableView(frame: frame, style: .plain)
        super.init(parent: parent, info: info)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
#if !os(tvOS)
        self.tableView.separatorStyle = .none
#endif
        self.tableView.allowsSelection = true
        self.tableView.backgroundColor = UIColor.clear
        
        if let value = info["itemH"] as? CGFloat {
            defaultItemHeight = value
        } else if let value = info["itemH"] as? String {
            defaultItemHeight = SwipeParser.parsePercent(value, full: screenDimension.height, defaultValue: defaultItemHeight)
        }

        if let itemsInfo = info["items"] as? [[String:Any]] {
            items = itemsInfo
            for _ in items {
                itemHeights.append(defaultItemHeight)
            }
        }
        if let scrollEnabled = self.info["scrollEnabled"] as? Bool {
            self.tableView.isScrollEnabled = scrollEnabled
        }
        self.tableView.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let selectedIndex = self.info["selectedItem"] as? Int {
                self.tableView.selectRow(at: IndexPath(row: selectedIndex, section: 0), animated: true, scrollPosition: .middle)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // UITableViewDataDelegate
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return itemHeights[indexPath.row]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let actions = parent!.eventHandler.actionsFor("rowSelected") {
            parent!.execute(self, actions: actions)
        }
    }
    
    // UITableViewDataSource
    
    var cellIndexPath: IndexPath?
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let subviewTag = 999
        self.cellIndexPath = indexPath
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
        if let subView = cell.contentView.viewWithTag(subviewTag) {
            subView.removeFromSuperview()
        }
        var cellError: String?
        
        let item = self.items[indexPath.row]
        
        if let itemH = item["h"] as? CGFloat {
            self.itemHeights[indexPath.row] = itemH
        }
        let itemHeight = self.itemHeights[indexPath.row]
        
        if let elementsInfo = item["elements"] as? [[String:Any]] {
            for elementInfo in elementsInfo {
                let element = SwipeElement(info: elementInfo, scale:self.scale, parent:self, delegate:self.delegate!)
                if let subview = element.loadViewInternal(CGSize(width: self.tableView.bounds.size.width, height: itemHeight), screenDimension: self.screenDimension) {
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
        
        cell.selectionStyle = .none
        self.cellIndexPath = nil
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    // SwipeView

    override func appendList(_ originator: SwipeNode, info: [String:Any]) {
        if let itemsInfoArray = info["items"] as? [[String:Any]] {
            var itemInfos = [[String:Any]]()

            for itemInfo in itemsInfoArray {
                if let _ = itemInfo["data"] as? [String:Any] {
                    var eval = originator.evaluate(itemInfo)
                    // if 'data' is a JSON string, use it, otherwise, use the info as is
                    if let dataStr = eval["data"] as? String, let data = dataStr.data(using: .utf8) {
                        do {
                            guard let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? [String:Any] else {
                                // 'data' is a plain String
                                itemInfos.append(eval)
                                break
                            }
                            
                            // 'data' is a JSON string so use the JSON object
                            if (json["elements"] as? [[String:Any]]) != nil {
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
            
            var urls = [URL:String]()

            for itemInfo in itemInfos {
                if let elementsInfo = itemInfo["elements"] as? [[String:Any]] {
                    let scaleDummy = CGSize(width: 0.1, height: 0.1)
                    
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
                self.tableView.scrollToRow(at: IndexPath(row: self.items.count - 1, section: 0), at: .bottom, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.tableView.scrollToRow(at: IndexPath(row: self.items.count - 1, section: 0), at: .bottom, animated: true)
                }
            }
        }
    }
    
    override func appendList(_ originator: SwipeNode, name: String, up: Bool, info: [String:Any])  -> Bool {
        if (name == "*" || self.name.caseInsensitiveCompare(name) == .orderedSame) {
            appendList(originator, info: info)
            return true
        }
        
        var node: SwipeNode? = self
        
        if up {
            while node?.parent != nil {
                if let viewNode = node?.parent as? SwipeView {
                    for c in viewNode.children {
                        if let e = c as? SwipeElement {
                            if e.name.caseInsensitiveCompare(name) == .orderedSame {
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
    
    override func getPropertyValue(_ originator: SwipeNode, property: String) -> Any? {
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
    
    override func getPropertiesValue(_ originator: SwipeNode, info: [String:Any]) -> Any? {
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
                    } else if let valInfo = item[itemStr] as? [String:Any] {
                        // ie "data":{...}
                        return originator.evaluate(valInfo)
                    }
                }
                // ie "property":{"items":{"data":{...}}}
                var path = info["items"] as! [String:Any]
                var property = path.keys.first!
                
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
