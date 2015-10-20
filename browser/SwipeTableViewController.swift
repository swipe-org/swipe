//
//  SwipeTableViewController.swift
//  sample
//
//  Created by satoshi on 10/8/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

class SwipeTableViewController: UITableViewController, SwipeDocumentViewer {
    private var document:[String:AnyObject]?
    private var sections = [[String:AnyObject]]()
    //private var items = [[String:AnyObject]]()
    private var url:NSURL?
    private weak var delegate:SwipeDocumentViewerDelegate?

    // <SwipeDocumentViewer> method
    func loadDocument(document:[String:AnyObject], url:NSURL?, state:[String:AnyObject]?) throws {
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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return self.sections.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let section = self.sections[section]
        guard let items = section["items"] as? [[String:AnyObject]] else {
            return 0
        }
        return items.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
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
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
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
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
