//
//  LineNumberRulerView.swift
//  Swifty
//
//  Created by Kyle Parisi on 7/3/20.
//  Copyright © 2020 Kyle Parisi. All rights reserved.
//

import AppKit

class LineNumberRulerView: NSRulerView {
    convenience init(textView: NSTextView) {
        self.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 12.0
    }

    override func drawHashMarksAndLabels(in _: NSRect) {
        guard let textView = clientView as? NSTextView,
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
            let charRangeOfLine = (textView.string as NSString).lineRange(for: NSRange(location: layoutManager.characterIndexForGlyph(at: firstGlyphOfLineIndex), length: 0))
            // Get the glyph range of the line we're currently in.
            let glyphRangeOfLine = layoutManager.glyphRange(forCharacterRange: charRangeOfLine, actualCharacterRange: nil)

            var firstGlyphOfRowIndex = firstGlyphOfLineIndex
            var lineWrapCount = 0

            // Loop through all rows (soft wraps) of the current line.
            while firstGlyphOfRowIndex < NSMaxRange(glyphRangeOfLine) {
                // The effective range of glyphs within the current line.
                var effectiveRange = NSRange(location: 0, length: 0)
                // Get the rect for the current line fragment.
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: firstGlyphOfRowIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

                // Draw the current line number;
                // When lineWrapCount > 0 the current line spans multiple rows.
                if lineWrapCount == 0 {
                    drawLineNumber(num: lineNumber, atYPosition: lineRect.minY)
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
            drawLineNumber(num: lineNumber, atYPosition: layoutManager.extraLineFragmentRect.minY)
        }
        
        // Determine max width for the gutter
        let largestNumber = NSAttributedString(string: String(lineNumber), attributes: [.font: textView.font!])
        let padding = CGFloat(20)
        let size = largestNumber.size().width.rounded(.up) + padding
        ruleThickness = size
        
    }

    func drawLineNumber(num: Int, atYPosition yPos: CGFloat) {
        // Unwrap the text view.
        guard let textView = clientView as? NSTextView,
            var font = textView.font else {
            return
        }
        let fontManager = NSFontManager.shared
        font = fontManager.convert(font, toHaveTrait: .unboldFontMask)
        font = fontManager.convert(font, toHaveTrait: .unitalicFontMask)
        font = fontManager.convert(font, toSize: 12.0)
        
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.right
        
        // Define attributes for the attributed string.
        let attrs = [NSAttributedString.Key.font: font, .foregroundColor: NSColor.gray, .paragraphStyle: paragraphStyle]
        // Define the attributed string.
        let attributedString = NSAttributedString(string: "\(num)", attributes: attrs)
        // Get the NSZeroPoint from the text view.
        let relativePoint = convert(NSZeroPoint, from: textView)
        
        // todo: fix these calculations to be based on the font size and gutter width
        attributedString.draw(in: NSRect(x: 0, y: relativePoint.y + yPos + 2, width: ruleThickness - 2, height: CGFloat(14)))
    }

    func refresh() {
        needsDisplay = true
    }
}
