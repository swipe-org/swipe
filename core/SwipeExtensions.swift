//
//  SwipeExtensions.swift
//  sample
//
//  Created by satoshi on 10/15/15.
//  Copyright © 2015 Satoshi Nakajima. All rights reserved.
//

import UIKit

extension String {
    var localized:String {
        return NSLocalizedString(self, comment:"")
    }
}

extension NSURL {
    static func url(urlString:String, baseURL:NSURL?) -> NSURL? {
        let url = NSURL(string: urlString, relativeToURL: baseURL)
        if let scheme = url?.scheme where scheme.characters.count > 0 {
            return url
        }
    
        var components = urlString.componentsSeparatedByString("/")
        if components.count == 1 {
            return NSBundle.mainBundle().URLForResource(urlString, withExtension: nil)
        }
        let filename = components.last
        components.removeLast()
        let dir = components.joinWithSeparator("/")
        return NSBundle.mainBundle().URLForResource(filename, withExtension: nil, subdirectory: dir)
    }
}
