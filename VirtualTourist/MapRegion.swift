//
//  MapRegion.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 2/1/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class MapRegion : NSManagedObject {

    struct Keys {

        static let id = "id"
        static let regionCenterLatitude = "regionCenterLatitude"
        static let regionCenterLongitude = "regionCenterLongitude"
        static let regionSpanLatitudeDelta = "regionSpanLatitudeDelta"
        static let regionSpanLongitudeDelta = "regionSpanLongitudeDelta"
    }

    @NSManaged var id: String!
    @NSManaged var regionCenterLatitude: NSNumber!
    @NSManaged var regionCenterLongitude: NSNumber!
    @NSManaged var regionSpanLatitudeDelta: NSNumber!
    @NSManaged var regionSpanLongitudeDelta: NSNumber!

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {

        // Prepare for Core Data Insert
        let entity =  NSEntityDescription.entityForName("MapRegion", inManagedObjectContext: context)!
        super.init(entity: entity,insertIntoManagedObjectContext: context)

        // Initialize the data elements for the Map Region Information

        id = "SavedMapRegionInformation"
        regionCenterLatitude = dictionary[Keys.regionCenterLatitude] as? NSNumber
        regionCenterLongitude = dictionary[Keys.regionCenterLongitude] as? NSNumber
        regionSpanLatitudeDelta = dictionary[Keys.regionSpanLatitudeDelta] as? NSNumber
        regionSpanLongitudeDelta = dictionary[Keys.regionSpanLongitudeDelta] as? NSNumber
    }

}
