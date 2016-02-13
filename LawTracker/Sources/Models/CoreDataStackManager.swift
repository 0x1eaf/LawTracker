//
//  CoreDataStackManager.swift
//  VirtualTourist
//
//  Created by Varvara Mironova on 11/27/15.
//  Copyright © 2015 VarvaraMironova. All rights reserved.
//

import Foundation
import CoreData

private let kVTSQLFileName  = "LawTracker.sqlite"
private let kVTMomdFileName = "LawTracker"
private let kLTQueueName    = "CoreDataQueue"

class CoreDataStackManager {
    
    // MARK: - Shared Instance
    class func sharedInstance() -> CoreDataStackManager {
        struct Static {
            static let instance = CoreDataStackManager()
        }
        
        return Static.instance
    }
    
    class func coreDataQueue() -> dispatch_queue_t {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: dispatch_queue_t? = nil
        }
        
        dispatch_once(&Static.onceToken) {
            Static.instance = dispatch_queue_create(kLTQueueName, DISPATCH_QUEUE_SERIAL)
        }
        
        return Static.instance!
    }
    
    // MARK: - The Core Data stack. The code has been moved, unaltered, from the AppDelegate.
    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = NSBundle.mainBundle().URLForResource(kVTMomdFileName, withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        let coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent(kVTSQLFileName)
        
        print("sqlite path: \(url.path!)")
        
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            
            abort()
        }
        
        return coordinator
    }()
    
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        
        return managedObjectContext
    }()
    
    // MARK: - Core Data Saving support
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    func delete(object:NSManagedObject) {
        managedObjectContext.deleteObject(object)
    }
    
    func storeConvocations(convocations: [NSDictionary], completionHandler: (finished: Bool) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            for convocationArray in convocations {
                _ = LTConvocationModel(dictionary: convocationArray as! [String : AnyObject], context: self.managedObjectContext, entityName:"LTConvocationModel")
            }
            
            self.saveContext()
            
            completionHandler(finished: true)
        }
    }
    
    func storeLaws(laws: [NSDictionary], convocation: String, completionHandler: (finished: Bool) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            for lawArray in laws {
                var lawId = String()
                if let id = lawArray["id"] as? String {
                    lawId = id
                } else if let id = lawArray["id"] as? Int {
                    lawId = "\(id)"
                }
                
                if nil == LTLawModel.modelWithID(lawId, entityName: "LTLawModel") {
                    if var mutableLawArray = lawArray as? [String : AnyObject] {
                        mutableLawArray["convocation"] = convocation
                        _ = LTLawModel(dictionary: mutableLawArray, context: self.managedObjectContext, entityName:"LTLawModel")
                    }
                }
            }
            
            self.saveContext()
            
            completionHandler(finished: true)
        }
    }
    
    func storeCommittees(committees: [NSDictionary], convocation: String, completionHandler: (finished: Bool) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            for committeeArray in committees {
                var committeeId = String()
                if let id = committeeArray["id"] as? String {
                    committeeId = id
                } else if let id = committeeArray["id"] as? Int {
                    committeeId = "\(id)"
                }
                
                if nil == LTCommitteeModel.modelWithID(committeeId, entityName: "LTCommitteeModel") {
                    if var mutableCommitteeArray = committeeArray as? [String : AnyObject] {
                        mutableCommitteeArray["convocation"] = convocation
                        _ = LTCommitteeModel(dictionary: mutableCommitteeArray, context: self.managedObjectContext, entityName:"LTCommitteeModel")
                    }
                }
            }
            
            self.saveContext()
            
            completionHandler(finished: true)
        }
    }
    
    func storeInitiatorTypes(types: [String : AnyObject], completionHandler: (finished: Bool) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            for (key, value) in types {
                if nil == LTInitiatorTypeModel.modelWithID(key, entityName: "LTInitiatorTypeModel") {
                    let type = ["id": key, "title": value]
                    _ = LTInitiatorTypeModel(dictionary: type, context: self.managedObjectContext, entityName:"LTInitiatorTypeModel")
                }
            }
            
            self.saveContext()
            
            completionHandler(finished: true)
        }
    }
    
    func storePersons(persons: [NSDictionary], completionHandler: (finished: Bool) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            for person in persons {
            _ = LTPersonModel(dictionary: person as! [String : AnyObject], context: self.managedObjectContext, entityName:"LTPersonModel")
            }
            
            self.saveContext()
            
            completionHandler(finished: true)
        }
    }
    
    func storeChanges(date: NSDate, changes: [NSDictionary], completionHandler: (finished: Bool) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            let dateString = date.string("yyyy-MM-dd")
            for changeArray in changes {
                var changeId = dateString
                if let billID = changeArray["bill"] as? String {
                    changeId += billID
                } else if let billID = changeArray["bill"] as? Int {
                    changeId = "\(billID)"
                }
                
                if var mutableChangeArray = changeArray as? [String : AnyObject] {
                    mutableChangeArray["date"] = date
                    mutableChangeArray["id"] = changeId
                    _ = LTChangeModel(dictionary: mutableChangeArray, context: self.managedObjectContext)
                }
            }
            
            self.saveContext()
            
            completionHandler(finished: true)
        }
    }
    
    func clearEntity(entityName: String, completionHandler:(success: Bool, error: NSError?) -> Void) {
        let queue = CoreDataStackManager.coreDataQueue()
        dispatch_async(queue) {
            let fetchRequest = NSFetchRequest(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                if let persistentStoreCoordinator = self.persistentStoreCoordinator  as NSPersistentStoreCoordinator! {
                    try persistentStoreCoordinator.executeRequest(deleteRequest, withContext: self.managedObjectContext)
                    completionHandler(success: true, error: nil)
                }
            } catch let error as NSError {
                completionHandler(success: true, error: error)
            }
        }
    }

}
