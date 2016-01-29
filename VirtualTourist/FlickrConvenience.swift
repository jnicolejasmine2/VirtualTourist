//
//  FlickrConvenience.swift
//  OnTheMap
//
//  Created by Jeanne Nicole Byers on 1/4/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension FlickrClient {


    func requestFlickrPhotos( latitude: String, longitude: String, newPin: Bool,  pinNumberOfPhotos: Int?, pinID: String, pin: Pins, completionHandler: (documentsArray: [NSDictionary], success: Bool, errorString: String? ) -> Void) {

        // Left in and stored in case the Flickr page issue is resolved
        let flickrKeyValuePairsBbox = [
            "method": "flickr.photos.search",
            "api_key": "29a2ceb613c91743df22f8ccb4be9f28",
            "accuracy": "11",
            "privacy_filter": "1",
            "per_page": "300",
            "page": "1",
            "lat": latitude,
            "lon": longitude,
            "format": "json",
            "nojsoncallback": "1",
            "extras": "url_m"
        ]

        // Call Flickr for the photo request
        processFlickrRequest(flickrKeyValuePairsBbox) {parsedResult, error in

            // Check for Errors
            if let error = error {
                let errorMessage =  error.domain
                completionHandler(documentsArray: [], success: false,  errorString: errorMessage )
            } else {

                // No error but check for no photos
                guard let photosDictionary = parsedResult["photos"] as? NSDictionary,
                    photoArray = photosDictionary["photo"] as? [[String: AnyObject]]
                    else {
                        completionHandler(documentsArray: [], success: false,  errorString: "Cannot Find Keys or Photos" )
                        return
                }

                // No errors, photo found
                var totalPhotos = 0
                if let totalPhototsTemp = photosDictionary["total"] as? String {
                    totalPhotos = (totalPhototsTemp as NSString).integerValue
                }

                if totalPhotos >  0  {

                    // Commit the Pin to indicate the photos are being loaded, this turns off the New collection button in the detail view
                    dispatch_async(dispatch_get_main_queue(), {
                        pin.totalPhotos = totalPhotos
                        pin.photosLoadedIndicator = false

                        // Save the photos
                        CoreDataStackManager.sharedInstance().saveContext()
                    })

                    self.buildPhotoURLDocumentNameArray (photoArray, completionHandler: { documentsArray, success, errorString in
                        print("got here after doing the build array: \(success)" )
                        if success == false {

                            // Return success, indicating the photos could not be saved
                            completionHandler(documentsArray: [], success: false,  errorString: errorString)

                        } else {

                            //Return documents to they can be loaded into Photos
                            completionHandler(documentsArray: documentsArray, success: true,  errorString: errorString)
                        }
                    })
                 }
                // Commit the Pin to indicate the the load is complete, no photos were found
                dispatch_async(dispatch_get_main_queue(), {
                    pin.totalPhotos = totalPhotos
                    pin.photosLoadedIndicator = true

                    // Save the photos
                    CoreDataStackManager.sharedInstance().saveContext()
                })

            }
        }
    }





    // Get access to the documents folder and add the photo file name
    func imageFileURL(fileName: String) ->  NSURL {

        let dirPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]

        let pathArray = [dirPath, fileName]
        let fileURL =  NSURL.fileURLWithPathComponents(pathArray)!
        return fileURL
    }



    // Download the photo and add to Documents folder
    func addPhotoToDocuments (imageUrlString: String) -> String {

        let imageURL = NSURL(string: imageUrlString)
        var filename: String?
        if let imageData = NSData(contentsOfURL: imageURL!) {

            // Using unique ID for the document name
            let uniqueID = NSUUID()
            filename = uniqueID.UUIDString

            // Save image in documents folder
            if let fileURL = imageFileURL(filename!).path {
                NSFileManager.defaultManager().createFileAtPath(fileURL, contents: imageData,   attributes:nil)
            }
        }
        return filename!
    }


    // Delete photos for the pin when the pin is deleted
    func deletePhotosForAPin(pinID: String!, completionHandler: (success: Bool, errorString: String?) -> Void) {

        dispatch_async(dispatch_get_main_queue(), {

            // Prepare for the fetch of all photos for the pin
            let fetchRequest = NSFetchRequest(entityName: "Photos")
            fetchRequest.predicate = NSPredicate(format: "pinsID == %@", pinID)

            do {
                // Fetch all the photos for a pin
                let fetchedPhotos = try self.sharedContext.executeFetchRequest(fetchRequest) as! [Photos]

                // Loop through the photos deleting the photo from the documents folder
                let photoCount = fetchedPhotos.count

                print("delete photo count:\(photoCount)")

                for photoIndex in 0...(photoCount - 1) {

                    let photo = fetchedPhotos[photoIndex]

                    // If there is a photo in the document, continue to delete it
                    if photo.documentsThumbnailFileName != nil {

                        // Delete from documents folder if there was a photo saved
                        photo.resetPhotoDocument()

                        // Delete the photo from core data
                        self.sharedContext.deleteObject(photo)

                        // Save the changes to core data
                        CoreDataStackManager.sharedInstance().saveContext()
                    }
                }
            } catch {
                completionHandler(success: false,  errorString: "cannot fetch photos")
            }
        })

        completionHandler(success: true,  errorString: nil)
    }



    // Shared Context Helper
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }





    // There are two steps here, one to add the photos to the documents folder. Two, update the photo record
    // in core data.
    func buildPhotoURLDocumentNameArray (photoArray:[[String: AnyObject]], completionHandler: (documentsArray: [NSDictionary], success: Bool, errorString: String?) -> Void) {

        // initialize the photos array to nill so it is fresh for the new photos
        photoDocumentNamesDictionary = []

        let photoCount = photoArray.count
        var photoIndexStart = 0
        var photoIndexEnd = Constants.photosToDisplayOffsetZero


        // The defaults are used when there are less than a full album of photos.
        // Otherwise, we look for a random place to start selecting photos
        if photoCount > Constants.photosToDisplay {
            let numberOfAvailableStartingPhotos = UInt32(photoCount - Constants.photosToDisplayOffsetZero)
            photoIndexStart = Int(arc4random_uniform(numberOfAvailableStartingPhotos))
            photoIndexEnd = photoIndexStart + Constants.photosToDisplayOffsetZero
        }

        print("photoIndexStart: \(photoIndexStart) ")
        print("photoIndexEnd: \(photoIndexEnd) ")

        var trackingNumberOfPhotos = 0

        // Loop through up to the max downloaded photos
        for photoIndex in photoIndexStart...photoIndexEnd {

            // If there are no actual photos, just add without a flickr thumbnail value
            if trackingNumberOfPhotos >= photoCount {
                let dictionary = ["flickrURL": " ", "documentFilename": " "]
                photoDocumentNamesDictionary.append(dictionary)

            } else {

                let photoDictionary = photoArray[photoIndex] as [String: AnyObject]
                if let imageUrlString = photoDictionary["url_m"] as? String {

                    // Get the document and store in documents folder
                    let filename = addPhotoToDocuments(imageUrlString)

                    let dictionary: NSDictionary = ["flickrURL": imageUrlString,
                        "documentFilename": filename
                    ]

                    photoDocumentNamesDictionary.append(dictionary)
                }
            }
            ++trackingNumberOfPhotos 
        }
        print("photoDocumentNamesDictionary: \(photoDocumentNamesDictionary)")
        completionHandler(documentsArray: photoDocumentNamesDictionary, success: true,  errorString: nil)
    }




}
