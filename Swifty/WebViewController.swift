//
//  WebViewController.swift
//  Swifty
//
//  Created by Kyle Parisi on 5/30/20.
//  Copyright © 2020 Kyle Parisi. All rights reserved.
//

import AppKit
import WebKit
import Nautilus

class WebViewController: NSViewController {
    
    @IBOutlet weak var web: WKWebView!
    @IBOutlet var text: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let ptr = highlight("func main() {}", "go", "html", "monokai")
        let test = String(cString: ptr.r0)
        free(ptr.r0)
        free(ptr.r1)
        
        if let attributedString = try? NSAttributedString(data: Data(test.utf8), options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            text.textStorage?.append(attributedString)
        }
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
//        web.loadHTMLString(test, baseURL: nil)
    }
}

class MyTextView: NSTextView {
    
    override func didChangeText() {
        let string = self.textStorage?.string
        let highlighted = highlight(string, "go", "html", "monokai")
        let content = String(cString: highlighted.r0)
        print(content)
        free(highlighted.r0)
        free(highlighted.r1)
        let cursor = self.selectedRanges.first?.rangeValue.location
        if let attributedString = try? NSAttributedString(data: Data(content.utf8), options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            self.textStorage?.setAttributedString(attributedString)
            self.setSelectedRange(NSRange(location: cursor!, length: 0))
        }
    }
}
