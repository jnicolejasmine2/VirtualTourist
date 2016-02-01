//
//  constants.swift
//  VirtualTourist
//
//  Created by Jeanne Nicole Byers on 1/27/16.
//  Copyright © 2016 Jeanne Nicole Byers. All rights reserved.
//

struct Constants {

    // Number of cells (photos) in the album
    static let photosToDisplay = 21
    static let photosToDisplayOffsetZero = photosToDisplay - 1

    // Left in and stored in case the Flickr page issue is resolved
    static let flickrKeyValuePairsConstant = [
        "method": "flickr.photos.search",
        "api_key": "29a2ceb613c91743df22f8ccb4be9f28",
        "accuracy": "11",
        "privacy_filter": "1",
        "per_page": "300",
        "page": "1", 
        "format": "json",
        "nojsoncallback": "1",
        "extras": "url_m"
    ]


}
