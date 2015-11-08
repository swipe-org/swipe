//
//  SwipeAssetManager
//  Swipe
//
//  Created by satoshi on 10/9/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

#if os(OSX)
import Cocoa
#else
import UIKit
#endif

import CoreData

private func MyLog(text:String, level:Int = 0) {
    let s_verbosLevel = 0
    if level <= s_verbosLevel {
        NSLog(text)
    }
}


class SwipeAssetManager {
    static let instance = SwipeAssetManager()
    
    static func sharedInstance() -> SwipeAssetManager {
        return SwipeAssetManager.instance
    }

    lazy var applicationCachesDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var applicationLibraryDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.LibraryDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var urlFolder:NSURL = {
        let urlFolder = self.applicationCachesDirectory.URLByAppendingPathComponent("cache.swipe.net")
        let fm = NSFileManager.defaultManager()
        if !fm.fileExistsAtPath(urlFolder.path!) {
            try! fm.createDirectoryAtURL(urlFolder, withIntermediateDirectories: false, attributes: nil)
            try! urlFolder.setResourceValue(true, forKey:NSURLIsExcludedFromBackupKey)
        }
        return urlFolder
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = NSBundle.mainBundle().URLForResource("asset", withExtension: "momd")!
        //let modelURL = NSBundle.mainBundle().URLForResource("snasset", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let filename = "asset004.sqlite"
#if os(tvOS)
        let url = self.applicationCachesDirectory.URLByAppendingPathComponent(filename)
#else
        let url = self.applicationLibraryDirectory.URLByAppendingPathComponent(filename)
#endif
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            MyLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                MyLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }

    func loadAsset(url:NSURL, prefix:String, bypassCache:Bool, callback:((NSURL?, NSError!) -> Void)?) {
        assert(NSThread.currentThread() == NSThread.mainThread(), "thread error")
        
        if url.scheme == "file" {
            MyLog("SWAsset loadAsset with file: \(url.lastPathComponent!)", level:1)
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                callback?(url, nil)
            })
            return
        }
        //MyLog("SNAsset loadAsset url = \(url)")
        //MyLog("SNAsset context = \(managedObjectContext)")
        
        let request = NSFetchRequest(entityName: "Asset")
        request.predicate = NSPredicate(format: "url == %@", url.path!)
        do {
            let results = try managedObjectContext.executeFetchRequest(request)
            //MyLog("SNAsset count = \(results.count)")
            let entity : NSManagedObject
            let uuid : String
            if results.count == 0 {
                uuid = NSUUID().UUIDString + prefix
                entity = NSEntityDescription.insertNewObjectForEntityForName("Asset", inManagedObjectContext: managedObjectContext)
                entity.setValue(uuid, forKey: "uuid")
                entity.setValue(url.path, forKey: "url")
            } else {
                entity = results[0] as! NSManagedObject
                uuid = entity.valueForKey("uuid") as! String
                //MyLog("SNAsset found entity=\(uuid)")
            }
            entity.setValue(NSDate(), forKey: "lastModified")
            saveContext()
            
            let urlLocal = urlFolder.URLByAppendingPathComponent(uuid)
            let fm = NSFileManager.defaultManager()
            let loaded = entity.valueForKey("loaded") as? Bool
            let fileSize = entity.valueForKey("size") as? Int
            if !bypassCache && loaded == true && fm.fileExistsAtPath(urlLocal.path!) {
                MyLog("SWAsset reuse \(url.lastPathComponent!), \(fileSize)", level:1)
                // We should call it asynchronously, which the caller expects.
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    callback?(urlLocal, nil)
                })
            } else {
                MyLog("SWAsset loading \(url.lastPathComponent!)", level:1)
                let connection = SwipeConnection.connection(url, urlLocal:urlLocal, entity:entity)
                connection.load { (error: NSError!) -> Void in
                    if error == nil {
                        entity.setValue(true, forKey: "loaded")
                        try! urlLocal.setResourceValue(true, forKey:NSURLIsExcludedFromBackupKey)
                        self.saveContext()
                    }
                    callback?(urlLocal, error)
                }
            }
        } catch {
            MyLog("SNAsset loadAsset \(error)")
            callback?(nil, error as NSError)
        }
    }
    
    func wasFileLoaded(connection:SwipeConnection) {
        connection.entity.setValue(connection.fileSize, forKey: "size")
        saveContext()
    }

    func reduce(limit:Int, amount:Int) {
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            let fm = NSFileManager.defaultManager()
            let request = NSFetchRequest(entityName: "Asset")
            request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: true)]
            request.fetchLimit = limit + amount // Number of items to fetch extra, to limit the nubmer of entities to delete for each reduce
            do {
                if let entities = try self.managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                    if entities.count > limit {
                        for i in 0..<(entities.count-limit) {
                            let entity = entities[i]
                            if let date = entity.valueForKey("lastModified") as? NSDate, let uuid = entity.valueForKey("uuid") as? String {
                                MyLog("SNAsset reducing date=\(date), \(uuid)")
                                let urlLocal = self.urlFolder.URLByAppendingPathComponent(uuid)
                                do {
                                    try fm.removeItemAtURL(urlLocal)
                                } catch {
                                    MyLog("SWAsset reduce fail to remove (totally fine)")
                                }
                                self.managedObjectContext.deleteObject(entity)
                            }
                        }
                    }
                }
            } catch {
                MyLog("SWAsset reduce fetch failed (something is wrong)")
            }
        }
    }
    
    func flush() {
        let fm = NSFileManager.defaultManager()
        do {
            let urls = try fm.contentsOfDirectoryAtURL(urlFolder, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            for url in urls {
                MyLog("SNAsset deleting url=\(url.lastPathComponent!)", level: 1)
                do {
                    try fm.removeItemAtURL(url)
                } catch {
                    MyLog("SWAsset flush failed to remove (something is wrong)")
                }
            }
        } catch {
            MyLog("SWAsset flush contentsOfDir failed (somethign is wrong)")
        }

        let request = NSFetchRequest(entityName: "Asset")
        do {
            if let entities = try managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] {
                MyLog("SNAsset flush count=\(entities.count)", level:1)
                for entity in entities {
                    managedObjectContext.deleteObject(entity)
                }
                saveContext()
            }
        } catch {
            MyLog("SWAsset flush fetch failed (something is wrong)")
        }
    }
}
