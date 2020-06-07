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

extension NSColor {
    convenience init?(hex: String) {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return nil
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

class WebViewController: NSViewController {
    
    @IBOutlet weak var web: WKWebView!
    @IBOutlet var text: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let style = "solarized-dark"
        let colorsptr = colors(style)
        print(colorsptr)
        let bg = String(cString: colorsptr.bg)
        let fg = String(cString: colorsptr.fg)
        text.backgroundColor = NSColor(hex: bg) ?? NSColor.gray
        text.insertionPointColor = NSColor(hex: fg) ?? NSColor.white
        free(colorsptr.bg)
        free(colorsptr.fg)
        let ptr = highlight("func main() {}", "go", style)
        let test = String(cString: ptr.r0)
        free(ptr.r0)
        free(ptr.r1)
        
        
        if let attributedString = try? NSAttributedString(data: Data(test.utf8), options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            text.textStorage?.append(attributedString)
        }
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
    }
}

class MyTextView: NSTextView {
    override func awakeFromNib() {
        // gutter
        self.enclosingScrollView?.verticalRulerView = LineNumberRulerView(textView: self)
        self.enclosingScrollView?.hasHorizontalRuler = false
        self.enclosingScrollView?.hasVerticalRuler   = true
        self.enclosingScrollView?.rulersVisible      = true
    }
    
    override func didChangeText() {
        let string = self.textStorage!.string
        let highlighted = highlight(string, "go", "github")
        let content = String(cString: highlighted.r0)
        free(highlighted.r0)
        free(highlighted.r1)
        let cursor = self.selectedRanges.first?.rangeValue.location
        print(content)
        if let attributedString = try? NSAttributedString(data: Data(content.utf8), options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
//            print(attributedString)
            self.textStorage?.setAttributedString(attributedString)
            self.setSelectedRange(NSRange(location: cursor!, length: 0))
        }
//        (self.enclosingScrollView?.verticalRulerView as! LineNumberRulerView).refresh()
    }
}

class LineNumberRulerView: NSRulerView {
    convenience init(textView: NSTextView) {
        self.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        print("draw")
        let textView = self.clientView as? NSTextView
        let visibleGlyphsRange = textView?.layoutManager?.glyphRange(forBoundingRect: textView!.visibleRect, in: textView!.textContainer!)
        print(visibleGlyphsRange ?? "")
        let attributedString = NSAttributedString(string: "1")
        attributedString.draw(at: NSPoint(x: 5, y: 5))
    }
    
    func refresh() {
        self.needsDisplay = true
    }
}
