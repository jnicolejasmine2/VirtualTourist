//
//  DetailViewController.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/1/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData


class DetailViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate, UICollectionViewDelegate {

    // Outlets
    @IBOutlet weak var detailMapView: MKMapView!
    @IBOutlet weak var photoCollectionView: UICollectionView!

    @IBOutlet weak var backToMapButton: UIBarButtonItem!
    @IBOutlet weak var newCollectionButton: UIButton!

    @IBOutlet weak var noPhotoView: UIView!

    // Variables
    var selectedPin: Pins?

    // Keep the changes. We will keep track of insertions, deletions, and updates.
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!


    // ***** VIEW CONTROLLER MANAGEMENT  **** //

    override func viewDidLoad() {
        super.viewDidLoad()

        print("selected Pin: \(selectedPin)")

        // Fetch the photos for the Pin
        do {
            try fetchedResultsController.performFetch()
        } catch {

            // Present an alert to let the user know we could not load photos
            self.presentAlert("Unable to Load Photos for the Pin", includeOK: true )
        }

        // Set the fetchedResultsController and collection delegates
        fetchedResultsController.delegate = self
        photoCollectionView.delegate = self

        // Fetch the Pin so that we can use the automatic core update to manage the new collection button
        do {
            try fetchedResultsControllerPin.performFetch()
        } catch {

            // Present an alert to let the user know we could not load photos
            // self.presentAlert("Unable to Load the Pin", includeOK: true )  <<---- jnb
        }

        // Set the fetchedresultscontroller for the pin
        fetchedResultsControllerPin.delegate = self

        // If the photos are not loaded disable the new collection button
        if selectedPin!.photosLoadedIndicator == false {
            newCollectionButton.enabled = false
        }

        // Check for pin having no photos. If none, display the view with the message and disable the new collection button
        if selectedPin?.totalPhotos == 0 && selectedPin?.photosLoadedIndicator == true {

            // Show the view with message
            noPhotoView.hidden = false

            // disable the New Collection Button
            newCollectionButton.hidden = true

        } else {

            // hide the view so the collection shows
            noPhotoView.hidden = true

            // disable the New Collection Button
            if selectedPin?.photosLoadedIndicator == true {
                newCollectionButton.hidden = false
                newCollectionButton.enabled = true
            }

            // Reload the collection
            photoCollectionView.reloadData()
        }

        // Create the mini-map at the top of the view 
        // shows a zoomed view of the pin that was selected
        detailMapView.delegate = self

        detailMapView.removeAnnotations(detailMapView.annotations)
        mapViewLoad()
    }




    // ***** BUTTON MANAGEMENT  **** //


    // Back button selected, dismiss view controller
    @IBAction func backToMapSelected(sender: AnyObject) {

        self.dismissViewControllerAnimated(true, completion: nil)
    }



    // New Collection button was touched, load new pins
    @IBAction func newCollectionAction(sender: AnyObject) {

        // Disable the button so the user cannot keep selecting it
        // Will be enabled when the pin is updated
        newCollectionButton.enabled = false
   
        dispatch_async(dispatch_get_main_queue(), {


            // Update the pin to indicate the load is started, this disables the New Collection button

            self.selectedPin!.photosLoadedIndicator = false
            CoreDataStackManager.sharedInstance().saveContext()


            // stop collection from being touched while load is going on
            self.photoCollectionView.allowsSelection = false
            self.photoCollectionView.scrollEnabled = false

 /****           // Remove the documents -- tried this but it is the same issue
            for photo in self.fetchedResultsController.fetchedObjects as! [Photos] {
                    photo.documentsThumbnailFileName = nil
            }

            // Save the changes
            //      CoreDataStackManager.sharedInstance().saveContext()   ***/

            print("should be reloading here-- Need to replace with activity indicators")
            self.photoCollectionView.reloadData()
        })

        // Load new photos for the pin
        loadPinPhotos()
    }



    // Get the Photos from Flickr, save in documents and update the photos
    func loadPinPhotos() {

        print("loadPinPhotosBeing")

        let pinTotalPhotos = selectedPin!.totalPhotos as? Int 
        let latitude = selectedPin!.latitude.stringValue
        let longitude = selectedPin!.longitude.stringValue


        // Call Flickr to get the photos
        FlickrClient.sharedInstance().requestFlickrPhotos( latitude, longitude: longitude, newPin: false, pinNumberOfPhotos: pinTotalPhotos, pinID: selectedPin!.id!, pin: selectedPin!, completionHandler: {documentsArray, success, errorString in
            print("GotHereentering: \(success)")
            // Check if we were able to get photos. If not, remove pin and present alert
            if success == true  {

                dispatch_async(dispatch_get_main_queue(), {
                    self.selectedPin!.photosLoadedIndicator = true
                    CoreDataStackManager.sharedInstance().saveContext()
                })

                //print("DocumentsArray in Detail: \(documentsArray)")
                print("Document array count: \(documentsArray.count)")

                var documentArrayIndex = 0
                for photo in self.fetchedResultsController.fetchedObjects as! [Photos] {

                    // Load up the photo name and then save 
                    let documentDictionary = documentsArray[documentArrayIndex]
                    let filename = documentDictionary["documentFilename"] as? String
                    let flickrThumbnailPath = documentDictionary["flickrURL"] as? String

                    print("filename \(documentArrayIndex): \(filename)")

                    dispatch_async(dispatch_get_main_queue(), {
                        photo.documentsThumbnailFileName = filename
                        photo.flickrThumbnailPath = flickrThumbnailPath

                    })

                    ++documentArrayIndex
                }
                dispatch_async(dispatch_get_main_queue(), {
                    CoreDataStackManager.sharedInstance().saveContext()
                })


                // Save the photos
                print("GotHereleaving")
                // Update the pin to indicate the load is done, this enables the New Collection button



            } else {

                // Present an alert to let the user know we could not load photos
                self.presentAlert("Unable to Load Photos from Flickr!", includeOK: true )
            }
        })
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
        self.detailMapView.addAnnotations(annotations)
    }



    // ***** COLLECTION MANAGEMENT  **** //


    // Number of Items set to the number of fetched results
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects

    }


    // Load the images into the collection
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

        // Using a custom cell
        let cell: PhotoCell = collectionView.dequeueReusableCellWithReuseIdentifier("CustomCollectionCell", forIndexPath: indexPath) as! PhotoCell

        // Stop Animating Activity Indicator incase it was left on
        cell.activityIndicator.stopAnimating()

        // Get the photo that is being formatted
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as? Photos

        print("IndexPath: \(indexPath)")

        if selectedPin!.photosLoadedIndicator == false {
            print("False load indicator")
            cell.activityIndicator.startAnimating()
        } else {
            if let photoFound = photo {

                // Check if Photo has been downloaded
                if photoFound.flickrThumbnailPath == nil || photoFound.flickrThumbnailPath ==  " "   {
                    print("FlickrTHumbnail= nil")
                    // No photo was available, should not happen but if it does, put out a white background
                    cell.collectionCellImage.image = UIImage(named: "whiteBackground")

                } else {

                    let photoDocumentsFileName = photoFound.documentsThumbnailFileName

                    // Photo has not been downloaded yet, show an activity indicator in the cell
                    if photoDocumentsFileName == nil || photoDocumentsFileName == " "  {
                        print("photoDocumentsFileName= nil")
                        cell.activityIndicator.startAnimating()

                    } else {
                        print("photoDocumentsFileName = \(photoDocumentsFileName!)")
                        // Photo is downloaded, put the image from the documents folder into the cell
                        let photoDocumentsUrl = self.imageFileURL(photoDocumentsFileName!).path
                        let photoImage = UIImage(contentsOfFile: photoDocumentsUrl!)

                        cell.collectionCellImage.image = photoImage
                    }
                }
            } else {

                print("No Photo Found")
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



    // When a photo is selected, it must be deleted
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {

        // stop other photos from being selected until delete is finished 
        photoCollectionView.allowsSelection = false
        photoCollectionView.scrollEnabled = false

        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photos


        // Changing the key to a later date moves the picture to the end.  The next step blanks it out and "deletes" it
        photo.photoID = NSDate()

        // Save the changes
        CoreDataStackManager.sharedInstance().saveContext()


        // sets the photo to delete status, flickr thumbnail and file name nil as well as deletes from documents folder
        photo.resetPhotoDocument()

        // Save the changes
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



    // Fetch all saved Pins
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

            //Insert new photo
            case .Insert:

                // Add to array, collection will be updated at the end of all the updates
               // insertedIndexPaths.append(newIndexPath!)
                self.photoCollectionView.insertItemsAtIndexPaths([newIndexPath!])

                break

            // Photo was deleted, delete photo from documents folder,
            case .Delete:

                // Remove the annotation when the pin was deleted
                if objectName == "Photos"  {

                    // Add to array, collection will be updated at the end of all the updates
                  //  deletedIndexPaths.append(indexPath!)
                    self.photoCollectionView.deleteItemsAtIndexPaths([indexPath!])

                    // allow other photos to be deleted now that delete is complete
                    self.photoCollectionView.allowsSelection = true
                    self.photoCollectionView.scrollEnabled = true

                }
                break

            // Update:
            case .Update:

                print(".update")

                // Called when an object is updated, typically this is when the photo is finally downloaded. 
                // All updates are held and run at the end
                if objectName == "Photos" {
                    print("photo.update.indexPath: \(indexPath)")
                  //  updatedIndexPaths.append(indexPath!)

                    self.photoCollectionView.reloadItemsAtIndexPaths([indexPath!])

                    // stop others from being selected until delete is finished
                    self.photoCollectionView.allowsSelection = true
                    self.photoCollectionView.scrollEnabled = true

                }

                // Pin was updated, this means that all the photos are downloaded and the New Collection button can be enabled
                if objectName == "Pins" {

                    let pin = fetchedResultsControllerPin.objectAtIndexPath(indexPath!) as! Pins

                    if pin.photosLoadedIndicator == true {

                        if selectedPin?.totalPhotos == 0 {
                            // Show the view with message
                            noPhotoView.hidden = false

                            // disable the New Collection Button
                            newCollectionButton.hidden = true

                        } else  {
                            // hide the view so the collection shows
                            noPhotoView.hidden = true

                            newCollectionButton.enabled = true
                            // Free up the collection to be selected
                            photoCollectionView.allowsSelection = true
                            photoCollectionView.scrollEnabled = true
                        }

                    } else {

                        // Disable the newCollection Button
                        newCollectionButton.enabled = false
                        // stop other photos from being selected until delete is finished
                        photoCollectionView.allowsSelection = false
                        photoCollectionView.scrollEnabled = false
                    }
                }
                break

            // Move: Used when deleting a photo, first it is moved ot end and the blanked out
            case .Move:

                // Move the photo immediately
                if objectName == "Photos" {
                    photoCollectionView.moveItemAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
                }
                break
            }
        }

/****  Removed batching trying to see if that would fix collection issue
    // Updates to the photos in core data are starting, start with fresh arrays.
    func controllerWillChangeContent(controller: NSFetchedResultsController) {

        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }


    // Performing collection updates in batch move
    func controllerDidChangeContent(controller: NSFetchedResultsController) {

        photoCollectionView.performBatchUpdates({() -> Void in

            // Photo inserted cells to replace those being deleted
            for indexPath in self.insertedIndexPaths {
                self.photoCollectionView.insertItemsAtIndexPaths([indexPath])
            }


            // Photo deleted cells need to be deleted
            for indexPath in self.deletedIndexPaths {

                self.photoCollectionView.deleteItemsAtIndexPaths([indexPath])

                // allow other photos to be deleted now that delete is complete
                self.photoCollectionView.allowsSelection = true
                self.photoCollectionView.scrollEnabled = true
            }

            // Photos updated (image downloaded), reload and present the image
            for indexPath in self.updatedIndexPaths {

                self.photoCollectionView.reloadItemsAtIndexPaths([indexPath])

                // stop others from being selected until delete is finished
                self.photoCollectionView.allowsSelection = true
                self.photoCollectionView.scrollEnabled = true
            }

            }, completion: nil)
    }

***/


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
