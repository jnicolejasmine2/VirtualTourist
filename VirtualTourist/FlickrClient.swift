//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/3/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

import Foundation
import SystemConfiguration
import CoreData

class FlickrClient: NSObject, NSFetchedResultsControllerDelegate   {

    // Array of document names, used to load photos into Core Data
    var photoDocumentNamesArray: [String?] = []

    var photoDocumentNamesDictionary: [NSDictionary] = []


    var session: NSURLSession
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }


    // Call to FLickr to return photos for the pin location
    func processFlickrRequest(valuePairs: [String: String], completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask  {

        let session = NSURLSession.sharedSession()
        let BASE_URL = "https://api.flickr.com/services/rest/"
        let urlString = BASE_URL + buildURL(valuePairs)

        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)


        // Initialize task for getting data
        let task = session.dataTaskWithRequest(request) { (data, response, error) in

            // Was there an error?
            guard (error == nil) else {
                completionHandler(result: nil, error: NSError(domain:  "Your request returned an invalid response!", code: 1, userInfo: nil))
                return
            }

            // Manage the return code
            let statusCode = (response as? NSHTTPURLResponse)?.statusCode

            if statusCode  < 200 || statusCode > 300  {
                if let response = response as? NSHTTPURLResponse {
                    completionHandler(result: nil, error: NSError(domain: "Your request returned an invalid response! Status code: \(response.statusCode)!", code: 1, userInfo: nil))

                } else if let response = response {
                    completionHandler(result: nil, error: NSError(domain: "Your request returned an invalid response! Response: \(response)!", code: 1, userInfo: nil))

                } else {
                    completionHandler(result: nil, error: NSError(domain:  "Your request returned an invalid response!", code: 1, userInfo: nil))
                }
                return
            }

            // No data returned
            guard let data = data else {
                completionHandler(result: nil, error: NSError(domain:  "Photos not found", code: 1, userInfo: nil))
                return
            }

            // Parse the data and use the data (happens in completion handler)
            self.parseJSONWithCompletionHandler(data, completionHandler: completionHandler)
        }

        // Resume (execute) the task
        task.resume()

        return task
    }


    // Build the URL to send to Flickr
    func buildURL (keyValues: [String:String]) -> String {

        var outputURL =  [String]()

        for (key, value) in keyValues {

            // Make sure that it is a string value
            let stringValue = "\(value)"

            // Escape it
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())

            // Append it
            outputURL += [key + "=" + "\(escapedValue!)"]

        }
        return (!outputURL.isEmpty ? "?" : "") + outputURL.joinWithSeparator("&")
    }



    // Given raw JSON, return a usable Foundation object
    func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {

        var parsedResult: AnyObject!
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandler(result: nil, error: NSError(domain: "parseJSONWithCompletionHandler", code: 1, userInfo: userInfo))
        }

        completionHandler(result: parsedResult, error: nil)
    }



    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }


}
