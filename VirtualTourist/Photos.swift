//
//  Photos.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/1/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//
import UIKit
import CoreData

class Photos : NSManagedObject {

    struct Keys {
        static let photoID = "photoID"
        static let pinsID = "pinsID"
        static let flickrThumbnailPath = "flickrThumbnailPath"
        static let documentsThumbnailFileName = "documentsThumbnailFileName"
    }

    @NSManaged var photoID: NSDate?
    @NSManaged var flickrThumbnailPath: String?
    @NSManaged var documentsThumbnailFileName: String?
    @NSManaged var pinsID: String?
    @NSManaged var pin: Pins?


    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {

        // Prepare for Core Data Insert
        let entity =  NSEntityDescription.entityForName("Photos", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        // Initialize the data elements for the Photo, using Date for sort for Photo
        pinsID = dictionary[Keys.pinsID] as! String?
        photoID = NSDate()
        flickrThumbnailPath = dictionary[Keys.flickrThumbnailPath] as? String
        documentsThumbnailFileName = dictionary[Keys.documentsThumbnailFileName] as? String
     }

    // Function to set the photo to deleted status and to remove from documents directory
    func resetPhotoDocument() {

        if documentsThumbnailFileName != nil {

            let fileURL = self.imageFileURL(documentsThumbnailFileName!).path!

            do {
                try NSFileManager.defaultManager().removeItemAtPath(fileURL )
            }
            catch {}

            flickrThumbnailPath = nil
            documentsThumbnailFileName = nil
        }
    }



    // Build the URL to retrieve the photo from the documents folder
    func imageFileURL(fileName: String) ->  NSURL {

        let dirPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let pathArray = [dirPath, fileName]
        let fileURL =  NSURL.fileURLWithPathComponents(pathArray)!

        return fileURL
    }

}
