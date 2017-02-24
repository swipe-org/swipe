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

private func MyLog(_ text:String, level:Int = 0) {
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

    lazy var applicationCachesDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    lazy var applicationLibraryDirectory: URL = {
        let urls = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    lazy var urlFolder:URL = {
        var urlFolder = self.applicationCachesDirectory.appendingPathComponent("cache.swipe.net")
        let fm = FileManager.default
        if !fm.fileExists(atPath: urlFolder.path) {
            try! fm.createDirectory(at: urlFolder, withIntermediateDirectories: false, attributes: nil)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try! urlFolder.setResourceValues(resourceValues)
        }
        return urlFolder
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "asset", withExtension: "momd")!
        //let modelURL = NSBundle.mainBundle().URLForResource("snasset", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let filename = "asset004.sqlite"
#if os(tvOS)
        let url = self.applicationCachesDirectory.appendingPathComponent(filename)
#else
        let url = self.applicationLibraryDirectory.appendingPathComponent(filename)
#endif
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: Any]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error
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
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
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

    func loadAsset(_ url:URL, prefix:String, bypassCache:Bool, callback:((URL?, NSError?) -> Void)?) {
        assert(Thread.current == Thread.main, "thread error")
        
        if url.scheme == "file" {
            MyLog("SWAsset loadAsset with file: \(url.lastPathComponent)", level:1)
            DispatchQueue.main.async(execute: { () -> Void in
                callback?(url, nil)
            })
            return
        }
        //MyLog("SNAsset loadAsset url = \(url)")
        //MyLog("SNAsset context = \(managedObjectContext)")
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Asset")
        request.predicate = NSPredicate(format: "url == %@", url.path)
        do {
            let results = try managedObjectContext.fetch(request)
            //MyLog("SNAsset count = \(results.count)")
            let entity : NSManagedObject
            let uuid : String
            if results.count == 0 {
                uuid = UUID().uuidString + prefix
                entity = NSEntityDescription.insertNewObject(forEntityName: "Asset", into: managedObjectContext)
                entity.setValue(uuid, forKey: "uuid")
                entity.setValue(url.path, forKey: "url")
            } else {
                entity = results[0]
                uuid = entity.value(forKey: "uuid") as! String
                //MyLog("SNAsset found entity=\(uuid)")
            }
            entity.setValue(Date(), forKey: "lastModified")
            saveContext()
            
            var urlLocal = urlFolder.appendingPathComponent(uuid)
            let fm = FileManager.default
            let loaded = entity.value(forKey: "loaded") as? Bool
            let fileSize = entity.value(forKey: "size") as? Int
            if !bypassCache && loaded == true && fm.fileExists(atPath: urlLocal.path) {
                MyLog("SWAsset reuse \(url.lastPathComponent), \(fileSize)", level:1)
                // We should call it asynchronously, which the caller expects.
                DispatchQueue.main.async(execute: { () -> Void in
                    callback?(urlLocal, nil)
                })
            } else {
                MyLog("SWAsset loading \(url.lastPathComponent)", level:1)
                let connection = SwipeConnection.connection(url, urlLocal:urlLocal, entity:entity)
                connection.load { (error: NSError!) -> Void in
                    if error == nil {
                        entity.setValue(true, forKey: "loaded")
                        var resourceValues = URLResourceValues()
                        resourceValues.isExcludedFromBackup = true
                        try! urlLocal.setResourceValues(resourceValues)
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
    
    func wasFileLoaded(_ connection:SwipeConnection) {
        connection.entity.setValue(connection.fileSize, forKey: "size")
        saveContext()
    }

    func reduce(_ limit:Int, amount:Int) {
        DispatchQueue.global(qos: .default).async { () -> Void in
            let fm = FileManager.default
            let request = NSFetchRequest<NSManagedObject>(entityName: "Asset")
            request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: true)]
            request.fetchLimit = limit + amount // Number of items to fetch extra, to limit the nubmer of entities to delete for each reduce
            do {
                let entities = try self.managedObjectContext.fetch(request)
                if entities.count > limit {
                    for i in 0..<(entities.count-limit) {
                        let entity = entities[i]
                        if let date = entity.value(forKey: "lastModified") as? Date, let uuid = entity.value(forKey: "uuid") as? String {
                            MyLog("SNAsset reducing date=\(date), \(uuid)")
                            let urlLocal = self.urlFolder.appendingPathComponent(uuid)
                            do {
                                try fm.removeItem(at: urlLocal)
                            } catch {
                                MyLog("SWAsset reduce fail to remove (totally fine)")
                            }
                            self.managedObjectContext.delete(entity)
                        }
                    }
                }
            } catch {
                MyLog("SWAsset reduce fetch failed (something is wrong)")
            }
        }
    }
    
    func flush() {
        let fm = FileManager.default
        do {
            let urls = try fm.contentsOfDirectory(at: urlFolder, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
            for url in urls {
                MyLog("SNAsset deleting url=\(url.lastPathComponent)", level: 1)
                do {
                    try fm.removeItem(at: url)
                } catch {
                    MyLog("SWAsset flush failed to remove (something is wrong)")
                }
            }
        } catch {
            MyLog("SWAsset flush contentsOfDir failed (somethign is wrong)")
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "Asset")
        do {
            let entities = try managedObjectContext.fetch(request)
            MyLog("SNAsset flush count=\(entities.count)", level:1)
            for entity in entities {
                managedObjectContext.delete(entity)
            }
            saveContext()
        } catch {
            MyLog("SWAsset flush fetch failed (something is wrong)")
        }
    }
}
