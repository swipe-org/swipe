//
//  SwipeTableViewController.swift
//  sample
//
//  Created by satoshi on 10/8/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX) // WARNING: OSX support is not done yet
import Cocoa
#else
import UIKit
#endif

private func MyLog(_ text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

//
// SwipeTableViewController is the "viewer" of documents with type "net.swipe.list"
//
class SwipeTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SwipeDocumentViewer {
    private var document:[String:AnyObject]?
    private var sections = [[String:AnyObject]]()
    //private var items = [[String:AnyObject]]()
    private var url:URL?
    private weak var delegate:SwipeDocumentViewerDelegate?
    private var prefetching = true
    @IBOutlet private var tableView:UITableView!
    @IBOutlet private var imageView:UIImageView?

    // Returns the list of URLs of required resouces for this element (including children)
    private lazy var resourceURLs:[URL:String] = {
        var urls = [URL:String]()
        for section in self.sections {
            guard let items = section["items"] as? [[String:AnyObject]] else {
                continue
            }
            for item in items {
                if let icon = item["icon"] as? String,
                    let url = URL.url(icon, baseURL: self.url) {
                    urls[url] = "" // no prefix
                }
            }
        }
        return urls
    }()

    lazy var prefetcher:SwipePrefetcher = {
        return SwipePrefetcher(urls:self.resourceURLs)
    }()
        
    // <SwipeDocumentViewer> method
    func loadDocument(_ document:[String:AnyObject], size:CGSize, url:URL?, state:[String:AnyObject]?, callback:(Float, NSError?)->(Void)) throws {
        self.document = document
        self.url = url
        if let sections = document["sections"] as? [[String:AnyObject]] {
            self.sections = sections
        } else if let items = document["items"] as? [[String:AnyObject]] {
            let section = [ "items":items ]
            sections.append(section)
        } else {
            throw SwipeError.invalidDocument
        }
        callback(1.0, nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let imageView = self.imageView {
            let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            effectView.frame = imageView.frame
            effectView.autoresizingMask = UIViewAutoresizing([.flexibleWidth, .flexibleHeight])
            imageView.addSubview(effectView)
        }

        self.prefetcher.start { (completed:Bool, _:[URL], _:[NSError]) -> Void in
            if completed {
                MyLog("SWTable prefetch complete", level:1)
                self.prefetching = false
                self.tableView.reloadData()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let size = self.tableView.bounds.size
        if let value = document?["rowHeight"] as? CGFloat {
            self.tableView.rowHeight = value
        } else if let value = document?["rowHeight"] as? String {
            self.tableView.rowHeight = SwipeParser.parsePercent(value, full: size.height, defaultValue: self.tableView.rowHeight)
        }
    }
    
    // <SwipeDocumentViewer> method
    func documentTitle() -> String? {
        return document?["title"] as? String
    }
    
    // <SwipeDocumentViewer> method
    func setDelegate(_ delegate:SwipeDocumentViewerDelegate) {
        self.delegate = delegate
    }
    
    // <SwipeDocumentViewer> method
    func hideUI() -> Bool {
        return false
    }

    // <SwipeDocumentViewer> method
    func landscape() -> Bool {
        return false
    }

    // <SwipeDocumentViewer> method
    func becomeZombie() {
        // no op
    }

    // <SwipeDocumentViewer> method
    func saveState() -> [String:AnyObject]? {
        return nil
    }

    // <SwipeDocumentViewer> method
    func languages() -> [[String:AnyObject]]? {
        return nil
    }
    
    // <SwipeDocumentViewer> method
    func reloadWithLanguageId(_ langID:String) {
        // no operation for this case
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return prefetching ? 0 : self.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let section = self.sections[section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return 0
        }
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "foo")

        // Configure the cell...
        let section = self.sections[(indexPath as NSIndexPath).section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return cell
        }
        let item = items[(indexPath as NSIndexPath).row]
        if let title = item["title"] as? String {
            cell.textLabel!.text = title
        } else if let url = item["url"] as? String {
            cell.textLabel!.text = url
        }
        if let icon = item["icon"] as? String,
            let url = URL.url(icon, baseURL: self.url),
            let urlLocal = self.prefetcher.map(url),
            let image = UIImage(contentsOfFile: urlLocal.path) {
            cell.imageView?.image = image
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = self.sections[(indexPath as NSIndexPath).section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return
        }
        let item = items[(indexPath as NSIndexPath).row]
        if let urlString = item["url"] as? String,
           let url = URL.url(urlString, baseURL: self.url) {
            self.delegate?.browseTo(url)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = self.sections[section]
        return section["title"] as? String
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
