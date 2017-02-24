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

extension URL {
    static func url(_ urlString:String, baseURL:URL?) -> URL? {
        let url = URL(string: urlString, relativeTo: baseURL)
        if let scheme = url?.scheme, scheme.characters.count > 0 {
            return url
        }
    
        var components = urlString.components(separatedBy: "/")
        if components.count == 1 {
            return Bundle.main.url(forResource: urlString, withExtension: nil)
        }
        let filename = components.last
        components.removeLast()
        let dir = components.joined(separator: "/")
        return Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: dir)
    }
}
