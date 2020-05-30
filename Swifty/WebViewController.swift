//
//  WebViewController.swift
//  Swifty
//
//  Created by Kyle Parisi on 5/30/20.
//  Copyright © 2020 Kyle Parisi. All rights reserved.
//

import Foundation
import Cocoa
import WebKit
import Nautilus

class WebViewController: NSViewController {
    
    @IBOutlet weak var web: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let ptr = highlight("func main() {}", "go", "html", "monokai")
        let test = String(cString: ptr.r0)
        free(ptr.r0)
        free(ptr.r1)
        web.loadHTMLString(test, baseURL: nil)
    }
}
