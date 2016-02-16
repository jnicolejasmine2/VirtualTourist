//
//  CollectionViewController..swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/1/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData


class CollectionViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate, UICollectionViewDelegate {

    // Outlets
    @IBOutlet weak var detailMapView: MKMapView!
    @IBOutlet weak var photoCollectionView: UICollectionView!

    @IBOutlet weak var backToMapButton: UIBarButtonItem!
    @IBOutlet weak var newCollectionButton: UIButton!

    @IBOutlet weak var noPhotoView: UIView!


    // Variables
    var selectedPin: Pins?
    var numberOfPhotosDeleted: Int = 0

    var newCollectionProcessing: Bool = false


    // ***** VIEW CONTROLLER MANAGEMENT  **** //

    override func viewDidLoad() {
        super.viewDidLoad()

        // Fetch the photos for the Pin
        do {
            try fetchedResultsController.performFetch()

        } catch {
            presentAlert("Unable to Load Photos for the Pin", includeOK: true )
        }

        // Set the fetchedResultsController and collection delegates
        fetchedResultsController.delegate = self
        photoCollectionView.delegate = self

        // Fetch the Pin so that we can use the automatic core update to manage the new collection button
        do {
            try fetchedResultsControllerPin.performFetch()

        } catch {
            presentAlert("Unable to Load Photos for the Pin", includeOK: true )
        }

        // Set the fetchedresultscontroller for the pin
        fetchedResultsControllerPin.delegate = self

        // Routine that checks if there are photos, if they are loaded or not
        let photosLoaded = checkIfAllPhotosLoaded()

        // Check for pin having no photos. If none, display the view with the message and disable the new collection button
        if selectedPin!.photosLoadedIndicator == true && selectedPin!.totalPhotos == 0 {

            // Show the view with message
            noPhotoView.hidden = false

            // Hide the collection button
            hideShowNewCollectionButtion("Hide")


        } else {

            // hide the view so the collection shows
            noPhotoView.hidden = true

            // Check if the photos have been loaded
            if photosLoaded == "NotLoaded" || selectedPin!.photosLoadedIndicator == false {

                // Hide the new collection button until all photos are loaded
                hideShowNewCollectionButtion("Hide")

            } else {
                // All photos loaded, show the collection button
                hideShowNewCollectionButtion("Show")

             }

            // Load the collection
            photoCollectionView.reloadData()
        }

        // Create the mini-map at the top of the view 
        // shows a zoomed view of the pin that was selected
        detailMapView.delegate = self

        detailMapView.removeAnnotations(detailMapView.annotations)
        mapViewLoad()
    }


    // Check to see if all the photos have been loaded.
    func checkIfAllPhotosLoaded() -> String {
        var count = 0

        let sectionInfo = fetchedResultsController.sections![0]
        let numberOfCurrentPhotos = sectionInfo.numberOfObjects

        // Check if documents are loaded
        if numberOfCurrentPhotos > 0 {
            for photo in fetchedResultsController.fetchedObjects as! [Photos] {

                if photo.documentsThumbnailFileName == nil || photo.documentsThumbnailFileName == " " {

                    // return if the document has not been downloaded
                    return "NotLoaded"
                }
                else {
                    ++count
                }
            }

        } else {
            if newCollectionProcessing == true {
                return "NotLoaded"
            }
        }

        // Return No photos if the count is zero
        if count == 0 {
            return "NoPhotos"
        }

        // All the photos have been loaded
        return "AllLoaded"
    }




    // ***** BUTTON MANAGEMENT  **** //


    // Back button selected, dismiss view controller
    @IBAction func backToMapSelected(sender: AnyObject) {

        dismissViewControllerAnimated(true, completion: nil)
    }


    func hideShowNewCollectionButtion(action: String) {

        // Set the hidden property based on what was sent in a ction
        if action == "Show" {
            newCollectionButton.hidden = false
        } else {
            newCollectionButton.hidden = true
        }
    }


    // New Collection button was touched, load new pins
    @IBAction func newCollectionAction(sender: AnyObject) {

        // Hide the collection button
        hideShowNewCollectionButtion("Hide")

        let sectionInfo = fetchedResultsController.sections![0]
        let numberOfCurrentPhotos = sectionInfo.numberOfObjects

        // Remove the documents from the collection. They will be replaced with activity indicators
        dispatch_async(dispatch_get_main_queue(), {
            if numberOfCurrentPhotos > 0 {
                for photoIndex in (0...(numberOfCurrentPhotos - 1) ).reverse() {

                    let photo = self.fetchedResultsController.fetchedObjects![photoIndex] as! Photos
                    self.sharedContext.deleteObject(photo)
                    CoreDataStackManager.sharedInstance().saveContext()
                }
            }
        })

        // Set on to load activity indicators
        newCollectionProcessing = true

        // Reset number of photos deleted
        numberOfPhotosDeleted = 0

        // Load new photos for the pin
        loadPinPhotos()
    }



    // Get the Photos from Flickr, save in documents and update the photos
    func loadPinPhotos() {

        // Build placement entries so activity indicators can be displayed while we call Flickr
        BuildPhotosForThePin()

        let pinTotalPhotos = selectedPin!.totalPhotos as? Int 
        let latitude = selectedPin!.latitude.stringValue
        let longitude = selectedPin!.longitude.stringValue

        // Call Flickr to get the photos
        FlickrClient.sharedInstance().requestFlickrPhotos( latitude, longitude: longitude, newPin: false, pinNumberOfPhotos: pinTotalPhotos, pinID: selectedPin!.id!, pin: selectedPin!, completionHandler: {documentsArray,  arrayPinID, success, errorString in
            self.newCollectionProcessing = false

            // Photos were found
            if success == true  {

                // Loop throught the array to get the flickr URL, then download the photo, save
                // in documents folder, and update photo which will refresh the collection cell
                for documentArrayIndex in 0...(pinTotalPhotos! - 1) {

                    let photo = self.fetchedResultsController.fetchedObjects![documentArrayIndex] as! Photos

                    //Check for a photo URL
                    let flickrThumbnailPath = documentsArray[documentArrayIndex]
                    
                    if flickrThumbnailPath > " "  {

                        // Get flickr photo and save in documents
                        FlickrClient.sharedInstance().addPhotoToDocuments(flickrThumbnailPath, photo: photo, completionHandler: {filename in

                            // Photo downloaded, update the photo record
                            if filename > " " {

                                dispatch_async(dispatch_get_main_queue(), {

                                    // Set the document and URL names so that the collection can be updated
                                    photo.documentsThumbnailFileName = filename
                                    photo.flickrThumbnailPath = flickrThumbnailPath

                                    // Save the data
                                    CoreDataStackManager.sharedInstance().saveContext()
                                })
                            }
                        })
                    }
                }

                // All done loading the photos, show the collection button
                self.hideShowNewCollectionButtion("Show")

            } else {

                // Present an alert to let the user know we could not load photos
                self.presentAlert("Unable to Load Photos from Flickr!", includeOK: true )
            }
        })
    }



    // Build the photos, to insert cells so the activity indicator can be displayed
    func BuildPhotosForThePin() {

        // Build the initial photos for the pin
        let totalPhotos = selectedPin!.totalPhotos as! Int

        for _ in 0...(totalPhotos - 1) {

            let PhotoInsertDictionary: [String : AnyObject] = [
                Photos.Keys.pinsID: selectedPin!.id!,
                Photos.Keys.flickrThumbnailPath: " ",
                Photos.Keys.documentsThumbnailFileName: " "
            ]

            let _ = Photos(dictionary: PhotoInsertDictionary, context: self.sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }




    // ***** MAP MANAGEMENT  **** //


    // MapAnnotation View Build
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {

        let reuseId = "pin"

        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = UIColor.blueColor()
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }



    // No action for selecting the pin
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
     }



    // Build the map, set up all the annotations into an annotation array
    func mapViewLoad() {

        var annotations = [MKPointAnnotation]()

        // Pin's location coordinates
        let latitude = CLLocationDegrees(selectedPin!.latitude!.doubleValue)
        let longitude = CLLocationDegrees(selectedPin!.longitude!.doubleValue)
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Set region
        let span = MKCoordinateSpanMake(0.4, 0.4)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        detailMapView.setRegion(region, animated: true)

        // create the annotation, set coordiates, title, and subtitle properties
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate

        // Add the new annotation to the array
        annotations.append(annotation)

        // When the array is complete, we add the annotations to the map
        detailMapView.addAnnotations(annotations)
    }



    // ***** COLLECTION MANAGEMENT  **** //


    // Number of Items set to the number of fetched results
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }


    // Load the images into the collection
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

        // Using a custom cell
        let cell: PhotoCell = collectionView.dequeueReusableCellWithReuseIdentifier("CustomCollectionCell", forIndexPath: indexPath) as! PhotoCell

        // Stop Animating Activity Indicator in case it was left on
        cell.activityIndicator.stopAnimating()

        // Get the photo that is being formatted
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as? Photos


        // If the photos are being downloaded, set the activity indicator
        if selectedPin!.photosLoadedIndicator == false  || newCollectionProcessing == true  {

            cell.collectionCellImage.image = UIImage(named: "whiteBackground")
            cell.activityIndicator.startAnimating()

        } else {
            if let photoFound = photo {

                // Check there is a photo to be downloaded. If not, set white space
                if photoFound.flickrThumbnailPath == nil || photoFound.flickrThumbnailPath ==  " "   {
                    // No photo was available, put out a white background
                    cell.collectionCellImage.image = UIImage(named: "whiteBackground")

                } else {

                    // Flickr has a photo
                    let photoDocumentsFileName = photoFound.documentsThumbnailFileName

                    // Photo has not been downloaded yet, show an activity indicator in the cell
                    if photoDocumentsFileName == nil || photoDocumentsFileName == " "  {
                        cell.collectionCellImage.image = UIImage(named: "whiteBackground")
                        cell.activityIndicator.startAnimating()

                    } else {
                        // Photo is downloaded, put the image from the documents folder into the cell
                        let photoDocumentsUrl = imageFileURL(photoDocumentsFileName!).path

                        // Check if photo is still in documents folder, if deleting all entries they can 
                        // be deleted while the collection is being updated
                        let manager = NSFileManager.defaultManager()
                        if (manager.fileExistsAtPath(photoDocumentsUrl!)) {

                            let photoImage = UIImage(contentsOfFile: photoDocumentsUrl!)
                            cell.collectionCellImage.image = photoImage

                        } else {
                            // No photo was available, put out a white background
                            cell.collectionCellImage.image = UIImage(named: "whiteBackground")
                        }
                    }
                }
            } else {

                // Photo in core data was not found. Should not happen but load a white background just in case
                cell.collectionCellImage.image = UIImage(named: "whiteBackground")
            }
        }
        return cell
    }



    // Build the URL to retrieve the photo from the documents folder
    func imageFileURL(fileName: String) ->  NSURL {

        let dirPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]

        let pathArray = [dirPath, fileName]
        let fileURL =  NSURL.fileURLWithPathComponents(pathArray)!

        return fileURL
    }



    // When a photo is selected, it must be deleted, I move it to the end, reset the photo so it is deleted from documents
    // The core data update routine will then blank out the photo 
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {

        // Add one to the number of deleted photos
        ++numberOfPhotosDeleted

         // Delete the pin
        let photoManagedObject = self.fetchedResultsController.fetchedObjects![indexPath.item] as! NSManagedObject
        self.sharedContext.deleteObject(photoManagedObject)

        CoreDataStackManager.sharedInstance().saveContext()
     }




    // ***** CORE DATA  MANAGEMENT - PHOTO  **** //


    // Shared Context Helper
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }


    // Fetch all saved Photos for the pin
    lazy var fetchedResultsController: NSFetchedResultsController = {

        let fetchRequest = NSFetchRequest(entityName: "Photos")

        let pinID = self.selectedPin!.id
        fetchRequest.predicate = NSPredicate(format: "pinsID == %@", pinID!);

        // Sort by photoID which is an ascending date
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "photoID", ascending: true)]

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)

        return fetchedResultsController
    }()



    // Fetch the selected Pin
    lazy var fetchedResultsControllerPin: NSFetchedResultsController = {

        let fetchRequest = NSFetchRequest(entityName: "Pins")

        // fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]

        let pinID = self.selectedPin!.id
        fetchRequest.predicate = NSPredicate(format: "id == %@", pinID!);
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)

        return fetchedResultsController
    }()



    // Called when core data is modified
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType,newIndexPath: NSIndexPath?) {

            let objectName = anObject.entity.name

            switch type {

            // Insert a new photo
            case .Insert:
                photoCollectionView.insertItemsAtIndexPaths([newIndexPath!])
                break

            // Deleting a photo
            case .Delete:
              photoCollectionView.deleteItemsAtIndexPaths([indexPath!])
            break


            case .Update:
                // Called when an object is updated, typically this is when the photo is finally downloaded.
                if objectName == "Photos"  {

                    // Reload the Cell
                    photoCollectionView.reloadItemsAtIndexPaths([indexPath!])

                    // Check if the photos have all  been loaded
                    let photosLoaded = checkIfAllPhotosLoaded()

                    if photosLoaded == "NotLoaded" {

                        // All photos have not been downloaded
                        // Hide the new collection button until all photos are loaded
                        hideShowNewCollectionButtion("Hide")


                    } else {
                        // All photos have been downloaded, show the new collection button
                        hideShowNewCollectionButtion("Show")

                    }
                }

                // Pin was updated, this means the total pins and/or the load indicator that flickr was called has been 
                // set.  Check for no photos again...
                if objectName == "Pins" {

                    let pin = fetchedResultsControllerPin.objectAtIndexPath(indexPath!) as! Pins

                    // Refresh the pin information
                    selectedPin = pin

                    // If we got here, flickr returned no images after we presented the view controller. Must switch the view
                    if pin.photosLoadedIndicator == true && pin.totalPhotos == 0 {

                        // Show the view with message
                        noPhotoView.hidden = false

                        // Hide the collection button
                        hideShowNewCollectionButtion("Hide")

                    }
                }
                break

            // Move
            case .Move:

                if objectName == "Photos" {
                    photoCollectionView.moveItemAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
                }
                break
            }
        }



    // ***** ALERT MANAGEMENT  **** //

    func presentAlert(alertMessage: String, includeOK: Bool ) {

        let alert = UIAlertController(title: "Alert", message: alertMessage, preferredStyle: UIAlertControllerStyle.Alert)

        // Option: OK
        if includeOK  {
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: {
                action in

                dispatch_async(dispatch_get_main_queue(), {
                    self.viewDidLoad()
                })
            }))
        }

        // Present the Alert!
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }


}
