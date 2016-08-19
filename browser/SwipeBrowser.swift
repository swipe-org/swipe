//
//  SwipeBrowser.swift
//  sample
//
//  Created by satoshi on 10/8/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX) // WARNING: OSX support is not done yet
import Cocoa
public typealias UIViewController = NSViewController
#else
import UIKit
#endif

//
// Change s_verbosLevel to 1 to see debug messages for this class
//
private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}

//
// This is the place you can add more document types. 
// Those UIViewControllers MUST support SwipeDocumentViewer protocol.
//
let g_typeMapping:[String:Void -> UIViewController] = [
    "net.swipe.list": { return SwipeTableViewController(nibName:"SwipeTableViewController", bundle:nil) },
    "net.swipe.swipe": { return SwipeViewController() },
]

//
// SwipeBrowser is the main UIViewController that is pushed into the navigation stack.
// SwipeBrowser "hosts" another UIViewController, which supports SwipeDocumentViewer protocol.
//
class SwipeBrowser: UIViewController, SwipeDocumentViewerDelegate {
    static var stack = [SwipeBrowser]()

#if os(iOS)
    private var fVisibleUI = true
    @IBOutlet var toolbar:UIView?
    @IBOutlet var bottombar:UIView?
    @IBOutlet var slider:UISlider!
    @IBOutlet var labelTitle:UILabel?
    private var landscapeMode = false
#elseif os(tvOS)
    override weak var preferredFocusedView: UIView? { return controller?.view }
#endif
    @IBOutlet var viewLoading:UIView?
    @IBOutlet var progress:UIProgressView?
    @IBOutlet var labelLoading:UILabel?
    @IBOutlet var btnLanguage:UIButton?

    private var resourceRequest:NSBundleResourceRequest?
    var url:NSURL? = NSBundle.mainBundle().URLForResource("index.swipe", withExtension: nil)
    var jsonDocument:[String:AnyObject]?
    var controller:UIViewController?
    var documentViewer:SwipeDocumentViewer?
    var ignoreViewState = false

    func browseTo(url:NSURL) {
        let browser = SwipeBrowser(nibName: "SwipeBrowser", bundle: nil)
        browser.url = url // 
        //MyLog("SWBrows url \(browser.url!)")

#if os(OSX)
        self.presentViewControllerAsSheet(browser)
#else
        self.presentViewController(browser, animated: true) { () -> Void in
            SwipeBrowser.stack.append(browser)
            MyLog("SWBrows push \(SwipeBrowser.stack.count)", level: 1)
        }
#endif
    }
    
    deinit {
        if let request = self.resourceRequest {
            request.endAccessingResources()
        }
        MyLog("SWBrows deinit", level:1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewLoading?.alpha = 0
        btnLanguage?.enabled = false

        if SwipeBrowser.stack.count == 0 {
            SwipeBrowser.stack.append(self) // special case for the first one
            MyLog("SWBrows push first \(SwipeBrowser.stack.count)", level: 1)
        }
        
#if os(iOS)
        slider.hidden = true
#endif

        if let document = self.jsonDocument {
            self.openDocument(document, localResource: true)
        } else if let url = self.url {
            if url.scheme == "file" {
                if let data = NSData(contentsOfURL: url) {
                    self.openData(data, localResource: true)
                } else {
                    // On-demand resource support
                    if let urlLocal = NSBundle.mainBundle().URLForResource(url.lastPathComponent, withExtension: nil),
                           data = NSData(contentsOfURL: urlLocal) {
                        self.openData(data, localResource: true)
                    } else {
                        self.processError("Missing resource:".localized + "\(url)")
                    }
                }
            } else {
                let manager = SwipeAssetManager.sharedInstance()
                manager.loadAsset(url, prefix: "", bypassCache:true) { (urlLocal:NSURL?,  error:NSError!) -> Void in
                    if let urlL = urlLocal where error == nil,
                       let data = NSData(contentsOfURL: urlL) {
                        self.openData(data, localResource: false)
                    } else {
                        self.processError(error.localizedDescription)
                    }
                }
            }
        } else {
            MyLog("SWBrows nil URL")
            processError("No URL to load".localized)
        }
    }
    
    // NOTE: documentViewer and vc always points to the same UIController.
    private func loadDocumentView(documentViewer:SwipeDocumentViewer, vc:UIViewController, document:[String:AnyObject]) {
#if os(iOS)
        if let title = documentViewer.documentTitle() {
            labelTitle?.text = title
        } else {
            labelTitle?.text = url?.lastPathComponent
        }
#endif
        if let languages = documentViewer.languages() where languages.count > 0 {
            btnLanguage?.enabled = true
        }

        controller = vc
        self.addChildViewController(vc)
        vc.view.autoresizingMask = UIViewAutoresizing([.FlexibleWidth, .FlexibleHeight])
#if os(OSX)
        self.view.addSubview(vc.view, positioned: .Below, relativeTo: nil)
#else
        self.view.insertSubview(vc.view, atIndex: 0)
#endif
        var rcFrame = self.view.bounds
#if os(iOS)
        if documentViewer.hideUI() {
            let tap = UITapGestureRecognizer(target: self, action: #selector(SwipeBrowser.tapped))
            self.view.addGestureRecognizer(tap)
            hideUI()
        } else if let toolbar = self.toolbar, let bottombar = self.bottombar {
            rcFrame.origin.y = toolbar.bounds.size.height
            rcFrame.size.height -= rcFrame.origin.y + bottombar.bounds.size.height
        }
#endif
        vc.view.frame = rcFrame
    }
    
    private func openDocumentViewer(document:[String:AnyObject]) {
        var documentType = "net.swipe.swipe" // default
        if let type = document["type"] as? String {
            documentType = type
        }
        guard let type = g_typeMapping[documentType] else {
            return processError("Unknown type:".localized + "\(g_typeMapping[documentType]).")
        }
        let vc = type()
        guard let documentViewer = vc as? SwipeDocumentViewer else {
            return processError("Programming Error: Not SwipeDocumentViewer.".localized)
        }
        self.documentViewer = documentViewer
        documentViewer.setDelegate(self)
        do {
            let defaults = NSUserDefaults.standardUserDefaults()
            var state:[String:AnyObject]? = nil
            if let url = self.url where ignoreViewState == false {
                state = defaults.objectForKey(url.absoluteString) as? [String:AnyObject]
            }
            self.viewLoading?.alpha = 1.0
            self.labelLoading?.text = "Loading Network Resources...".localized
            try documentViewer.loadDocument(document, size:self.view.frame.size, url: url, state:state) { (progress:Float, error:NSError?) -> (Void) in
                self.progress?.progress = progress
                if progress >= 1 {
                    UIView.animateWithDuration(0.2, animations: { () -> Void in
                        self.viewLoading?.alpha = 0.0
                    }, completion: { (_:Bool) -> Void in
                        self.loadDocumentView(documentViewer, vc:vc, document: document)
                    })
                }
            }
            
        } catch let error as NSError {
            self.viewLoading?.alpha = 0.0
            return processError("Load Document Error:".localized + "\(error.localizedDescription).")
        }
    }
    
    private func openDocumentWithODR(document:[String:AnyObject], localResource:Bool) {
            if let tags = document["resources"] as? [String] where localResource {
                //NSLog("tags = \(tags)")
                let request = NSBundleResourceRequest(tags: Set<String>(tags))
                self.resourceRequest = request
                request.conditionallyBeginAccessingResourcesWithCompletionHandler() { (resourcesAvailable:Bool) -> Void in
                    MyLog("SWBrows resourceAvailable(\(tags)) = \(resourcesAvailable)", level:1)
                    dispatch_async(dispatch_get_main_queue()) {
                        if resourcesAvailable {
                            self.openDocumentViewer(document)
                        } else {
                            let alert = UIAlertController(title: "Swipe", message: "Loading Resources...".localized, preferredStyle: UIAlertControllerStyle.Alert)
                            self.presentViewController(alert, animated: true) { () -> Void in
                                request.beginAccessingResourcesWithCompletionHandler() { (error:NSError?) -> Void in
                                    dispatch_async(dispatch_get_main_queue()) {
                                        self.dismissViewControllerAnimated(false, completion: nil)
                                        if let e = error {
                                            MyLog("SWBrows resource error=\(error)", level:0)
                                            return self.processError(e.localizedDescription)
                                        } else {
                                            self.openDocumentViewer(document)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                self.openDocumentViewer(document)
            }
    }
    
    private func openDocument(document:[String:AnyObject], localResource:Bool) {
        var deferred = false
#if os(iOS)
        if let orientation = document["orientation"] as? String where orientation == "landscape" {
            self.landscapeMode = true
            if !localResource {
                // HACK ALERT: If the resource is remote and the orientation is landscape, it is too late to specify
                // the allowed orientations. Until iOS7, we could just call attemptRotationToDeviceOrientation(), 
                // but it no longer works. Therefore, we work-around by presenting a dummy VC, and dismiss it
                // before opening the document.
                deferred = true
                //UIViewController.attemptRotationToDeviceOrientation() // NOTE: attempt but not working
                let vcDummy = UIViewController()
                self.presentViewController(vcDummy, animated: false, completion: { () -> Void in
                    self.dismissViewControllerAnimated(false, completion: nil)
                    self.openDocumentWithODR(document, localResource: localResource)
                })
            }
        }
#endif
        if !deferred {
            self.openDocumentWithODR(document, localResource: localResource)
        }
    }
    
    private func openData(dataRetrieved:NSData?, localResource:Bool) {
        guard let data = dataRetrieved else {
            return processError("Failed to open: No data".localized)
        }
        do {
            guard let document = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String:AnyObject] else {
                return processError("Not a dictionary.".localized)
            }
            openDocument(document, localResource: localResource)
        } catch let error as NSError {
            let value = error.userInfo["NSDebugDescription"]!
            processError("Invalid JSON file".localized + "\(error.localizedDescription). \(value)")
            return
        }
    }
    
#if os(iOS)
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // NOTE: This function and supportedInterfaceOrientations will not be called on iPad
    // as long as the app supports multitasking.
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if let documentViewer = self.documentViewer where documentViewer.landscape() {
            return UIInterfaceOrientationMask.Landscape
        }
        return landscapeMode ?
            UIInterfaceOrientationMask.Landscape
            : UIInterfaceOrientationMask.Portrait
    }

    @IBAction func tapped() {
        MyLog("SWBrows tapped", level: 1)
        if fVisibleUI {
            hideUI()
        } else {
            showUI()
        }
    }
    
    private func showUI() {
        fVisibleUI = true
        UIView.animateWithDuration(0.2, animations: { () -> Void in
            self.toolbar?.alpha = 1.0
            self.bottombar?.alpha = 1.0
        })
    }
    
    private func hideUI() {
        fVisibleUI = false
        UIView.animateWithDuration(0.2, animations: { () -> Void in
            self.toolbar?.alpha = 0.0
            self.bottombar?.alpha = 0.0
        })
    }

    @IBAction func slided(sender:UISlider) {
        MyLog("SWBrows \(slider.value)")
    }
#else
    func tapped() {
    }
#endif

    private func processError(message:String) {
        dispatch_async(dispatch_get_main_queue()) {
#if !os(OSX) // REVIEW
            let alert = UIAlertController(title: "Can't open the document.", message: message, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (_:UIAlertAction) -> Void in
                self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            })
            self.presentViewController(alert, animated: true, completion: nil)
#endif
        }
    }
    
#if !os(OSX)
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
#endif
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        if self.isBeingDismissed() {
            if let documentViewer = self.documentViewer,
                   state = documentViewer.saveState(),
                   url = self.url {
                MyLog("SWBrows state=\(state)", level:1)
                let defaults = NSUserDefaults.standardUserDefaults()
                defaults.setObject(state, forKey: url.absoluteString)
                defaults.synchronize()
            }
        
            SwipeBrowser.stack.popLast()
            MyLog("SWBrows pop \(SwipeBrowser.stack.count)", level:1)
            if SwipeBrowser.stack.count == 1 {
                // Wait long enough (200ms > 1/30fps) and check the memory leak. 
                // This gives the timerTick() in SwipePage to complete the shutdown sequence
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(200 * NSEC_PER_MSEC)), dispatch_get_main_queue()) { () -> Void in
                    SwipePage.checkMemoryLeak()
                    SwipeElement.checkMemoryLeak()
                }
            }
        }
    }

    @IBAction func close(sender:AnyObject) {
#if os(OSX)
        self.presentingViewController!.dismissViewController(self)
#else
        self.presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
#endif
    }
    
    func becomeZombie() {
        if let documentViewer = self.documentViewer {
            documentViewer.becomeZombie()
        }
    }

    static func openURL(urlString:String) {
        NSLog("SWBrose openURL \(SwipeBrowser.stack.count) \(urlString)")
#if os(OSX)
        while SwipeBrowser.stack.count > 1 {
            let lastVC = SwipeBrowser.stack.last!
            lastVC.becomeZombie()
            SwipeBrowser.stack.last!.dismissViewController(lastVC)
        }
#else
        if SwipeBrowser.stack.count > 1 {
            let lastVC = SwipeBrowser.stack.last!
            lastVC.becomeZombie()
            SwipeBrowser.stack.last!.dismissViewControllerAnimated(false, completion: { () -> Void in
                openURL(urlString)
            })
            return
        }
#endif
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            if let url = NSURL.url(urlString, baseURL: nil) {
                SwipeBrowser.stack.last!.browseTo(url)
            }
        }
    }

    @IBAction func language() {
        if let languages = documentViewer?.languages() {
            let alert = UIAlertController(title: "Swipe", message: "Choose a language", preferredStyle: UIAlertControllerStyle.ActionSheet)
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = btnLanguage!.frame
            for language in languages {
                guard let title = language["title"] as? String,
                          langId = language["id"] as? String else {
                    continue
                }
                alert.addAction(UIAlertAction(title: title, style: UIAlertActionStyle.Default, handler: { (_:UIAlertAction) -> Void in
                    //print("SwipeB language selected \(langId)")
                    self.documentViewer?.reloadWithLanguageId(langId)
#if os(iOS)
                    self.hideUI()
#endif
                }))
            }
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }

    @IBAction func export() {
        guard let swipeVC = controller as? SwipeViewController else {
            return
        }
        let docURL = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let fileURL = docURL.URLByAppendingPathComponent("ani.gif")
        
        let exporter = SwipeExporter(swipeViewController: swipeVC, fps:4)
        exporter.exportAsGifAnimation(fileURL, startPage: swipeVC.book.pageIndex, pageCount: 3) { (complete, error) -> Void in
            if complete {
                print("GIF animation export done")
            } else if let error = error {
                print("Error", error)
            } else {
                print("progress", exporter.progress)
            }
        }
    }
}
