//
//  Pins.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/1/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//
import UIKit
import CoreData

class Pins : NSManagedObject {

    struct Keys {
        static let id = "id"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let totalPhotos = "totalPhotos"
        static let photosLoadedIndicator = "photosLoadedIndicator"
    }


    @NSManaged var id: String?
    @NSManaged var latitude: NSNumber!
    @NSManaged var longitude: NSNumber!
    @NSManaged var totalPhotos: NSNumber?
    @NSManaged var album: [Photos]
    @NSManaged var photosLoadedIndicator: Bool



    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {

        // Prepare for Core Data Insert
        let entity =  NSEntityDescription.entityForName("Pins", inManagedObjectContext: context)!
        super.init(entity: entity,insertIntoManagedObjectContext: context)

        // Initialize the data elements for the Pin
        id = dictionary[Keys.id] as? String
        latitude = dictionary[Keys.latitude] as? NSNumber
        longitude = dictionary[Keys.longitude] as? NSNumber
        photosLoadedIndicator = false
    }
}
