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

private func MyLog(text:String, level:Int = 0) {
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
    private var url:NSURL?
    private weak var delegate:SwipeDocumentViewerDelegate?
    private var prefetching = true
    @IBOutlet private var tableView:UITableView!
    @IBOutlet private var imageView:UIImageView?

    // Returns the list of URLs of required resouces for this element (including children)
    private lazy var resourceURLs:[NSURL:String] = {
        var urls = [NSURL:String]()
        for section in self.sections {
            guard let items = section["items"] as? [[String:AnyObject]] else {
                continue
            }
            for item in items {
                if let icon = item["icon"] as? String,
                       url = NSURL.url(icon, baseURL: self.url) {
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
    func loadDocument(document:[String:AnyObject], size:CGSize, url:NSURL?, state:[String:AnyObject]?, callback:(Float, NSError?)->(Void)) throws {
        self.document = document
        self.url = url
        if let sections = document["sections"] as? [[String:AnyObject]] {
            self.sections = sections
        } else if let items = document["items"] as? [[String:AnyObject]] {
            let section = [ "items":items ]
            sections.append(section)
        } else {
            throw SwipeError.InvalidDocument
        }
        callback(1.0, nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let imageView = self.imageView {
            let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .Light))
            effectView.frame = imageView.frame
            effectView.autoresizingMask = UIViewAutoresizing([.FlexibleWidth, .FlexibleHeight])
            imageView.addSubview(effectView)
        }

        self.prefetcher.start { (completed:Bool, _:[NSURL], _:[NSError]) -> Void in
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
    func setDelegate(delegate:SwipeDocumentViewerDelegate) {
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
    func reloadWithLanguageId(langID:String) {
        // no operation for this case
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return prefetching ? 0 : self.sections.count
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let section = self.sections[section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return 0
        }
        return items.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "foo")

        // Configure the cell...
        let section = self.sections[indexPath.section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return cell
        }
        let item = items[indexPath.row]
        if let title = item["title"] as? String {
            cell.textLabel!.text = title
        } else if let url = item["url"] as? String {
            cell.textLabel!.text = url
        }
        if let icon = item["icon"] as? String,
               url = NSURL.url(icon, baseURL: self.url),
               urlLocal = self.prefetcher.map(url),
               path = urlLocal.path,
               image = UIImage(contentsOfFile: path) {
            cell.imageView?.image = image
        }
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let section = self.sections[indexPath.section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return
        }
        let item = items[indexPath.row]
        if let urlString = item["url"] as? String,
           let url = NSURL.url(urlString, baseURL: self.url) {
            self.delegate?.browseTo(url)
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = self.sections[section]
        return section["title"] as? String
    }

    func tapped() {
        self.delegate?.tapped()
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
