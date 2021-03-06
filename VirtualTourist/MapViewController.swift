//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/1/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import CoreData


class MapViewController: UIViewController, UINavigationControllerDelegate, MKMapViewDelegate, NSFetchedResultsControllerDelegate  {

    // Outlets
    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var editMessageView: UIView!
    @IBOutlet weak var editDoneButton: UIBarButtonItem!

    // Current Pin ID
    var currentPinID: String!
    var currentPin: Pins?

    // Current Annotation selected
    var currentAnnotation: MKPointAnnotation? = nil

    // Indicator if we are in edit mode
    var currentEditMode: Bool = false

    // Fetched Photos
    var fetchedPhotos:[Photos] = []

    // Map Region 
    var fetchedMapRegion: [MapRegion] = []



    // ***** VIEW CONTROLLER MANAGEMENT  **** //

    override func viewDidLoad() {
        super.viewDidLoad()

        // Move edit message so it does not show
        editMessageView.hidden = true

        // set up Long Press so that a pin can be added
        let mapLPGR = UILongPressGestureRecognizer(target: self, action: "action:")
        mapLPGR.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(mapLPGR)

        // Fetch any existing Pins
        do {
            try fetchedResultsController.performFetch()
        } catch {}

        // Set the fetchedResultsController.delegate = self
        fetchedResultsController.delegate = self

        // Default map regions or set to last map view
        setMapRegions()

        // Add any saved pins to the map
        mapView.delegate = self
        mapView.removeAnnotations(mapView.annotations)
        mapViewLoad()
    }


    // Check if the app has the region information that was previously saved
    // If none, saved, set to the US view as default
    func setMapRegions() {

        var lastRegion = MKCoordinateRegion()

        let fetchRequest = NSFetchRequest(entityName: "MapRegion")
        fetchRequest.predicate = NSPredicate(format: "id == %@", "SavedMapRegionInformation")

        do {
            // Fetch the photos
            fetchedMapRegion = try sharedContext.executeFetchRequest(fetchRequest) as! [MapRegion]

            if  fetchedMapRegion == []  {

                // Default first time app is used to US view that was the default
                lastRegion.center.latitude = 37.13284
                lastRegion.center.longitude = -95.78558
                lastRegion.span.latitudeDelta =  73.9839134276936
                lastRegion.span.longitudeDelta = 61.2760164777852
            }
            else  {
                // Reopening app, set the last map region
                let currentRegionInfo: MapRegion = fetchedMapRegion [0]
                lastRegion.center.latitude = Double(currentRegionInfo.regionCenterLatitude)
                lastRegion.center.longitude = Double(currentRegionInfo.regionCenterLongitude)
                lastRegion.span.latitudeDelta = Double(currentRegionInfo.regionSpanLatitudeDelta)
                lastRegion.span.longitudeDelta = Double(currentRegionInfo.regionSpanLongitudeDelta)
            }

            // Update the map view
            mapView.setRegion(lastRegion, animated: true)
        } catch {}
    }



    // ***** GESTURE MANAGEMENT  **** //


    // Long Gesture Actions
    // Began: adds the pin to the map
    // Changed:  allows the pin to be dragged to a new location
    // Ended:  Starts the process to retrieve photos
    func action(gestureRecognizer: UIGestureRecognizer) {

        // Get the coordinates where user is touching
        let touchPoint = gestureRecognizer.locationInView(mapView)
        let newCoordinates = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)

        // State determines if the guesture is starting, changing or ending.
        let state = gestureRecognizer.state

        // Started: Add Pin to core data who will update the annotation view
        if state == .Began {

            // Save the pins to core data
            let dictionary: [String : AnyObject] = [
                Pins.Keys.id : NSUUID().UUIDString,
                Pins.Keys.latitude : newCoordinates.latitude,
                Pins.Keys.longitude : newCoordinates.longitude
            ]
            let _ = Pins(dictionary: dictionary, context: sharedContext)

            // Save the changes
            CoreDataStackManager.sharedInstance().saveContext()
        }


        // Changed (Dragging Pin): Pin is being dragged to a new location
        if state == .Changed {

            // Find the object that is being changed
            var indexNumber = 0

            for foundPin in fetchedResultsController.fetchedObjects as! [Pins] {

                if foundPin.id == currentPinID {

                    let pinManagedObject = fetchedResultsController.fetchedObjects![indexNumber] as! Pins

                    pinManagedObject.setValue(newCoordinates.latitude, forKey: "latitude")
                    pinManagedObject.setValue(newCoordinates.longitude, forKey: "longitude")

                    // Save the changes
                    CoreDataStackManager.sharedInstance().saveContext()
                    break
                }
                indexNumber += 1
            }
        }

        // Ended (Finger Lifted):
        if state == .Ended {

            let latitude = String(newCoordinates.latitude)
            let longitude = String(newCoordinates.longitude)

            // Find the pin that is being changed
            var indexNumber = 0
            for foundPin in fetchedResultsController.fetchedObjects as! [Pins] {

                if foundPin.id == currentPinID {

                    let pinManagedObject = fetchedResultsController.fetchedObjects![indexNumber] as! Pins
                    currentPin = pinManagedObject


                    // Start the process to get the photos
                    loadPinPhotos(latitude, longitude: longitude, currentIndex:indexNumber)
                    break

                }
                indexNumber += 1
            }
        }
    }




    // ***** BUTTON MANAGEMENT  **** //


    // Edit and Done button, move up/down the map and edit message
    @IBAction func editPinAction(sender: AnyObject) {

        // TURN EDIT MODE ON
        if currentEditMode == false {

            // Move the message view and map up
            editMessageView.frame.origin.y += 44
            editMessageView.hidden = false

            for _ in 1...44 {
                mapView.frame.origin.y -= 1
                editMessageView.frame.origin.y -= 1
            }

            // Toggle the edit mode so we know to delete vs show detail view
            currentEditMode = true

            // Switch button to done
            editDoneButton.title = "Done"

            // Do not allow new pins to be dropped while in Edit mode
            if let recognizers = mapView.gestureRecognizers {
                for recognizer in recognizers  {
                    mapView.removeGestureRecognizer(recognizer )
                }
            }

        } else {

            // TURN EDIT MODE OFF

            // Move the message view and map back down
            for _ in 1...44 {
                mapView.frame.origin.y += 1
                editMessageView.frame.origin.y += 1
            }
            editMessageView.frame.origin.y -= 44

            // Toggle the edit mode so we know to delete vs show photos
            currentEditMode = false

            // hide the edit message
            editMessageView.hidden = true

            // Switch button to Edit
            editDoneButton.title = "Edit"


            // Not edit mode, allow pins to drop
            // let mapLPGR = UILongPressGestureRecognizer(target: self, action: "action:")

            let mapLPGR = UILongPressGestureRecognizer(target: self, action: "action:")
            mapLPGR.minimumPressDuration = 1.0
            mapView.addGestureRecognizer(mapLPGR)
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
            pinView!.animatesDrop = true
            pinView!.draggable = true
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }


    // Annotation was selected.  If in Edit mode, delete the pin. If not in edit mode
    // present the photosViewController
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {

        let lat = view.annotation?.coordinate.latitude
        let long = view.annotation?.coordinate.longitude

        // save off current annotation so it can be deleted later
        currentAnnotation = view.annotation as? MKPointAnnotation

        // Not Edit Mode: Pin selected for viewing
        if currentEditMode == false  {

            var indexNumber = 0
            for foundPin in fetchedResultsController.fetchedObjects as! [Pins] {

                if foundPin.latitude == lat  && foundPin.longitude == long {

                    let pinManagedObject = fetchedResultsController.fetchedObjects![indexNumber] as! Pins

                    let nextController = storyboard!.instantiateViewControllerWithIdentifier("CollectionViewController") as! CollectionViewController

                    // Pass the pin information to the detail view controller
                    nextController.selectedPin = pinManagedObject

                    // Deselect the pin so that when returning can reselect it
                    mapView.deselectAnnotation(view.annotation!, animated: true)

                    // Present the view controller
                    presentViewController(nextController, animated: true, completion: nil)

                    break
                }
                indexNumber += 1
            }

        } else {
            // Edit Mode: find the pin that is being changed and delete it
            var indexNumber = 0
            for foundPin in fetchedResultsController.fetchedObjects as! [Pins] {

                if foundPin.latitude == lat  && foundPin.longitude == long {

                    // Delete all the photos for a Pin
                    FlickrClient.sharedInstance().deletePhotosForAPin(foundPin.id, completionHandler: { success, errorString in

                        if success == true {

                            // Delete the pin
                            let pinManagedObject = self.fetchedResultsController.fetchedObjects![indexNumber] as! Pins
                            self.sharedContext.deleteObject(pinManagedObject)

                            // Save the data
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                    })
                    break
                }
                indexNumber += 1
            }
        }
    }



    // When the map view is changed, save off the region information to be used when app is reopened
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {

        // Check if have saved map region information. If not, build the record and read it to be used later
        if fetchedMapRegion == []  {

            let MapRegionInsertDictionary: [String : AnyObject] = [
                MapRegion.Keys.regionCenterLatitude : mapView.region.center.latitude,
                MapRegion.Keys.regionCenterLongitude : mapView.region.center.longitude,
                MapRegion.Keys.regionSpanLatitudeDelta : mapView.region.span.latitudeDelta,
                MapRegion.Keys.regionSpanLongitudeDelta : mapView.region.span.longitudeDelta
            ]
            let _ = MapRegion(dictionary: MapRegionInsertDictionary, context: self.sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()

            // Fetch so any updates will find it
            let fetchRequest = NSFetchRequest(entityName: "MapRegion")
            fetchRequest.predicate = NSPredicate(format: "id == %@", "SavedMapRegionInformation")

            do {
                // Fetch the photos
                fetchedMapRegion = try sharedContext.executeFetchRequest(fetchRequest) as! [MapRegion]
            }
            catch {}

        } else {

            // Update the core data
            let currentRegionInfo: MapRegion = fetchedMapRegion [0]

            currentRegionInfo.regionCenterLatitude = mapView.region.center.latitude
            currentRegionInfo.regionCenterLongitude = mapView.region.center.longitude
            currentRegionInfo.regionSpanLatitudeDelta = mapView.region.span.latitudeDelta
            currentRegionInfo.regionSpanLongitudeDelta = mapView.region.span.longitudeDelta

            CoreDataStackManager.sharedInstance().saveContext()
        }
    }



    // First time in, build the map, set up all the annotations using Pin information in the fetched results into an annotation array
    func mapViewLoad() {

        var annotations = [MKPointAnnotation]()

        // Loop through pins  and load the annotations
        for foundPin in fetchedResultsController.fetchedObjects as! [Pins] {
            let latitude = CLLocationDegrees(foundPin.latitude)
            let longitude = CLLocationDegrees(foundPin.longitude)
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let annotation = MKPointAnnotation()

            annotation.coordinate = coordinate

            // Add the new annotation to the array
            annotations.append(annotation)
        }

        // When the array is complete, add the annotations to the map
        mapView.addAnnotations(annotations)
    }




    // ***** CORE DATA  MANAGEMENT  **** //

    // Shared Context Helper
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }




    // Get the Photos from Flickr
    func loadPinPhotos(latitude: String!, longitude: String!, currentIndex: Int!) {

        // Fetch the photos so we can update them with the document ID
        BuildFetchPhotosForThePin()

        let pinTotalPhotos = currentPin!.totalPhotos as? Int

        // Call Flickr to get the photos
        FlickrClient.sharedInstance().requestFlickrPhotos( latitude, longitude: longitude, newPin: true, pinNumberOfPhotos: pinTotalPhotos, pinID: currentPin!.id!, pin: currentPin!, completionHandler: {documentsArray, arrayPinID, success, errorString in


            dispatch_async(dispatch_get_main_queue(), {

                let fetchRequest = NSFetchRequest(entityName: "Photos")
                fetchRequest.predicate = NSPredicate(format: "pinsID == %@", arrayPinID)


                // Sort by photoID which is an ascending date
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "photoID", ascending: true)]

                do {
                    // Fetch all the photos so they can be updated once the photo is downloaded.

                    let fetchedPhotosWithPhotos = try self.sharedContext.executeFetchRequest(fetchRequest) as! [Photos]

                    // Determine how many photos were returned
                    var pinTotalURLLoop = 0
                    for  arrayItem in documentsArray {
                        if arrayItem > " " {
                            ++pinTotalURLLoop
                        }
                    }

                    // Loop through the photos, download the photo and set the flickr URL and document filename for each photo
                    if pinTotalURLLoop > 0 {
                        for photoIndex in 0...(pinTotalURLLoop - 1) {

                            let photo = fetchedPhotosWithPhotos[photoIndex]
                            let flickrThumbnailPath = documentsArray[photoIndex]

                            if flickrThumbnailPath > " " {

                                // Get flickr photo and save in documents
                                FlickrClient.sharedInstance().addPhotoToDocuments(flickrThumbnailPath, photo: photo, completionHandler: {filename in

                                    // Photo downloaded, update the photo record
                                    if filename > " " {
                                        dispatch_async(dispatch_get_main_queue(), {

                                            // Set the document and URL names so that the collection can be updated
                                            photo.documentsThumbnailFileName = filename
                                            photo.flickrThumbnailPath = flickrThumbnailPath
                                            CoreDataStackManager.sharedInstance().saveContext()
                                        })
                                    }
                                })
                            }
                        }
                    }


                    // Now that we know the actual number of photos, delete unused photos which were added originally to hold activity indicators
                    if pinTotalURLLoop < Constants.photosToDisplay {
                        for photoIndex in (pinTotalURLLoop)...Constants.photosToDisplayOffsetZero {
                            let photo = fetchedPhotosWithPhotos[photoIndex]

                            dispatch_async(dispatch_get_main_queue(), {

                                // Delete the photo from core data
                                self.sharedContext.deleteObject(photo)
                                CoreDataStackManager.sharedInstance().saveContext()
                            })
                        }
                    }
                } catch {
                    // Present an alert to let the user know we could not load photos
                    self.presentAlert("Unable to Load Photos from Flickr!", includeOK: true )
                }
            })
        })
    }



    // Build the photos first.  This is done so that activity indicators are visible while the initial call to Flickr is being done.
    func BuildFetchPhotosForThePin() {

        // Update the pin to indicate the load is started, this disables the New Collection button
        self.currentPin!.photosLoadedIndicator = false
        CoreDataStackManager.sharedInstance().saveContext()

        // Build the initial photos for the pin
        for _ in 0...Constants.photosToDisplayOffsetZero {
            let PhotoInsertDictionary: [String : AnyObject] = [
                Photos.Keys.pinsID : currentPin!.id!
            ]
            let _ = Photos(dictionary: PhotoInsertDictionary, context: self.sharedContext)
        }
        CoreDataStackManager.sharedInstance().saveContext()
     }



    // Fetch all saved Pins
    lazy var fetchedResultsController: NSFetchedResultsController = {

        let fetchRequest = NSFetchRequest(entityName: "Pins")

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        return fetchedResultsController
    }()


    // Called when pin in core data is modified
    // For the annotation view,
    //      insert: adds an annotation when the pin is first created
    //      update: moves the annotation when the pin is moved(dragged)
    //      delete: deletes the annotation when the pin is deleted

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {

            let objectName = anObject.entity.name

            switch type {

            // Insert: adds an annotation to the map when it is first created
            case .Insert:

                if objectName == "Pins"  {
                     // Locate the new Pin
                    let newPin = controller.objectAtIndexPath(newIndexPath!) as! Pins

                    // Pin's location coordinates
                    let latitude = CLLocationDegrees(newPin.latitude)
                    let longitude = CLLocationDegrees(newPin.longitude)
                    let newCoordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                    // Add the annotation
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = newCoordinates
                    annotation.title = " "
                    currentPinID = newPin.id

                    currentAnnotation = annotation
                    mapView.addAnnotation(annotation)
                }
                break

            // Delete: deletes the annotation from the map when pin is deleted
            case .Delete:

                if objectName == "Pins" {
                    mapView.removeAnnotation(currentAnnotation!)
                }
                break

            // Update:: Move the pin on the map to simulate being dragged
            case .Update:
                if objectName == "Pins" {

                    // Locate the Pin
                    let updatePin = controller.objectAtIndexPath(indexPath!) as! Pins

                    // Pin's location coordinates
                    let latitude = CLLocationDegrees(updatePin.latitude)
                    let longitude = CLLocationDegrees(updatePin.longitude)
                    let newCoordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                    // let annotation = MKPointAnnotation()
                    let annotation = currentAnnotation
                    annotation!.coordinate = newCoordinates
                    currentPinID = updatePin.id
                }
                break

            // Moved:  Not used, just in case it is called, rebuild the map
            case .Move:
                // Note referenced but if so, rebuild the map
                if objectName == "Pins"  {
                    mapView.removeAnnotations(mapView.annotations)
                    mapViewLoad()
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
