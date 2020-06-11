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

let STYLE = "github"

class WebViewController: NSViewController {
    
    @IBOutlet weak var web: WKWebView!
    @IBOutlet var text: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let colorsptr = colors(STYLE)
        print(colorsptr)
        let bg = String(cString: colorsptr.bg)
        let fg = String(cString: colorsptr.fg)
        text.backgroundColor = NSColor(hex: bg) ?? NSColor.gray
        text.insertionPointColor = NSColor(hex: fg) ?? NSColor.white
        free(colorsptr.bg)
        free(colorsptr.fg)
        let ptr = highlight("func main() {}", "go", STYLE)
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

class MyTextStorage: NSTextStorage {

    private var isBusyProcessing = false
    private var storage: NSTextStorage
    
    override init() {
        storage = NSTextStorage()
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is not supported")
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("\(#function) has not been implemented")
    }
    
    override var string: String {
        return storage.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
        endEditing()
    }
    
    override func processEditing() {
        self.isBusyProcessing = true
        defer { self.isBusyProcessing = false }

        // processSyntaxHighlighting()

        super.processEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {

       // When we are processing, `edited` callbacks will
       // result in the caret jumping to the end of the document, so
       // do not send them!
       guard !isBusyProcessing else {
           storage.setAttributes(attrs, range: range)
           return
       }

       beginEditing()
       storage.setAttributes(attrs, range: range)
       self.edited(.editedAttributes, range: range, changeInLength: 0)
       endEditing()
   }
    
    func processSyntaxHighlighting() {}
}

class MyTextView: NSTextView {
    override func awakeFromNib() {
        self.layoutManager?.replaceTextStorage(MyTextStorage())
        // gutter
        self.enclosingScrollView?.verticalRulerView = LineNumberRulerView(textView: self)
        self.enclosingScrollView?.hasHorizontalRuler = false
        self.enclosingScrollView?.hasVerticalRuler   = true
        self.enclosingScrollView?.rulersVisible      = true
    }
    
    override func didChangeText() {
        let string = self.textStorage!.string
        let highlighted = highlight(string, "go", STYLE)
        let content = String(cString: highlighted.r0)
        free(highlighted.r0)
        free(highlighted.r1)
        let cursor = self.selectedRanges.first?.rangeValue.location
        if let attributedString = try? NSAttributedString(data: Data(content.utf8), options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
//            print(attributedString)
            self.textStorage?.setAttributedString(attributedString)
            self.setSelectedRange(NSRange(location: cursor!, length: 0))
        }
        (self.enclosingScrollView?.verticalRulerView as! LineNumberRulerView).refresh()
    }
}

class LineNumberRulerView: NSRulerView {
    convenience init(textView: NSTextView) {
        self.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        print("draw line numbers")
        guard let textView = self.clientView as? NSTextView,
        let layoutManager = textView.layoutManager,
        let textContainer = textView.textContainer
        else {
            return
        }
        
        let visibleGlyphsRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        
        // Check how many lines are out of the current bounding rect.
        var lineNumber: Int = 1
        do {
            let newlineRegex = try NSRegularExpression(pattern: "\n", options: [])
            // Check how many lines are out of view; From the glyph at index 0
            // to the first glyph in the visible rect.
            lineNumber += newlineRegex.numberOfMatches(in: textView.string, options: [], range: NSMakeRange(0, visibleGlyphsRange.location))
        } catch {
            return
        }
        
        // Get the index of the first glyph in the visible rect, as starting point...
        var firstGlyphOfLineIndex = visibleGlyphsRange.location
        
        // ...then loop through all visible glyphs, line by line.
        while firstGlyphOfLineIndex < NSMaxRange(visibleGlyphsRange) {
            // Get the character range of the line we're currently in.
            let charRangeOfLine  = (textView.string as NSString).lineRange(for: NSRange(location: layoutManager.characterIndexForGlyph(at: firstGlyphOfLineIndex), length: 0))
            // Get the glyph range of the line we're currently in.
            let glyphRangeOfLine = layoutManager.glyphRange(forCharacterRange: charRangeOfLine, actualCharacterRange: nil)

            var firstGlyphOfRowIndex = firstGlyphOfLineIndex
            var lineWrapCount        = 0

            // Loop through all rows (soft wraps) of the current line.
            while firstGlyphOfRowIndex < NSMaxRange(glyphRangeOfLine) {
              // The effective range of glyphs within the current line.
              var effectiveRange = NSRange(location: 0, length: 0)
              // Get the rect for the current line fragment.
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: firstGlyphOfRowIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

              // Draw the current line number;
              // When lineWrapCount > 0 the current line spans multiple rows.
              if lineWrapCount == 0 {
                self.drawLineNumber(num: lineNumber, atYPosition: lineRect.minY)
              } else {
                break
              }

              // Move to the next row.
              firstGlyphOfRowIndex = NSMaxRange(effectiveRange)
              lineWrapCount += 1
            }

            // Move to the next line.
            firstGlyphOfLineIndex = NSMaxRange(glyphRangeOfLine)
            lineNumber += 1
        }
        
        // Draw another line number for the extra line fragment.
        if let _ = layoutManager.extraLineFragmentTextContainer {
            self.drawLineNumber(num: lineNumber, atYPosition: layoutManager.extraLineFragmentRect.minY)
        }
    }
    
    func drawLineNumber(num: Int, atYPosition yPos: CGFloat) {
        // Unwrap the text view.
        guard let textView = self.clientView as? NSTextView,
            let font     = textView.font else {
        return
        }
        // Define attributes for the attributed string.
        let attrs = [NSAttributedString.Key.font: font]
        // Define the attributed string.
        let attributedString = NSAttributedString(string: "\(num)", attributes: attrs)
        // Get the NSZeroPoint from the text view.
        let relativePoint = self.convert(NSZeroPoint, from: textView)
        // Draw the attributed string to the calculated point.
        let point = NSPoint(x: 5, y: relativePoint.y + yPos)
        attributedString.draw(at: point)
    }
    
    func refresh() {
        self.needsDisplay = true
    }
}
