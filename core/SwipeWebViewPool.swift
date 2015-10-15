//
//  SwipeWebViewPool.swift
//  Swipe
//
//  Created by satoshi on 9/14/15.
//  Copyright (c) 2015 Satoshi Nakajima. All rights reserved.
//

/*
    This class was created to work-around a bug in iOS8. 
    If we create and delete WKWebView objects repeatedly, it eventually stops drawing.
*/

import UIKit
import WebKit

class SwipeWebViewPool {
    private static let singleton = SwipeWebViewPool()
    private var pool = [WKWebView]()
    
    static func sharedInstance() -> SwipeWebViewPool {
        return SwipeWebViewPool.singleton
    }

    func getWebView() -> WKWebView {
        if pool.count > 0 {
            let webView = pool.last!
            //NSLog("WVManager returning an instance \(pool.count)")
            pool.removeLast()
            return webView
        }
        //NSLog("WVManager returning a new instance")
        return WKWebView()
    }
    
    func storeWebView(webView:WKWebView) {
        pool.append(webView)
        //NSLog("WVManager storing an instance \(pool.count)")
    }
}
