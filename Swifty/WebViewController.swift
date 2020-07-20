//
//  WebViewController.swift
//  Swifty
//
//  Created by Kyle Parisi on 5/30/20.
//  Copyright © 2020 Kyle Parisi. All rights reserved.
//

import AppKit
import Nautilus

extension NSColor {
    convenience init(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count == 3 {
            let last = cString.last
            for _ in 3...6 {
                cString.append(last!)
            }
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

    convenience init(rgbValue: Int) {
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

}

struct Style: Decodable {
    let color: Int
}

struct Term: Decodable {
    let type: String
    let value: String
    let style: Style
}

class WebViewController: NSViewController {
    @IBOutlet var text: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
    }
}

class MyTextStorage: NSTextStorage {
    private var isBusyProcessing = false
    private var storage: NSMutableAttributedString

    override init() {
        storage = NSMutableAttributedString()
        super.init()
    }

    required init?(coder _: NSCoder) {
        fatalError("\(#function) is not supported")
    }

    required init?(pasteboardPropertyList _: Any, ofType _: NSPasteboard.PasteboardType) {
        fatalError("\(#function) has not been implemented")
    }

    override var string: String {
        return storage.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func processEditing() {
        isBusyProcessing = true
        defer { self.isBusyProcessing = false }

        processSyntaxHighlighting()

        super.processEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        // When we are processing, `edited` callbacks will
        // result in the caret jumping to the end of the document, so
        // do not send them!
        guard !isBusyProcessing else {
            storage.setAttributes(attrs, range: range)
            return
        }

        beginEditing()
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    func processSyntaxHighlighting() {
        let ptr = highlight(string, "go", "dracula")
        let test = String(cString: ptr.r0)
        free(ptr.r0)
        free(ptr.r1)
        let terms: [Term] = try! JSONDecoder().decode([Term].self, from: test.data(using: .utf8)!)
        var location = 0
        for term in terms {
            let range = NSRange(location: location, length: term.value.count)
            addAttributes([.foregroundColor: NSColor(rgbValue: term.style.color)], range: range)
            location += term.value.count
        }

    }
}

class MyTextView: NSTextView {
    override func awakeFromNib() {
        layoutManager?.replaceTextStorage(MyTextStorage())
        backgroundColor = NSColor(hex: "#000")
        textColor = NSColor(hex: "#000")
        insertionPointColor = NSColor(hex: "#fff")
        // gutter
        enclosingScrollView?.verticalRulerView = LineNumberRulerView(textView: self)
        enclosingScrollView?.hasHorizontalRuler = false
        enclosingScrollView?.hasVerticalRuler = true
        enclosingScrollView?.rulersVisible = true
    }

    override func didChangeText() {
        (enclosingScrollView?.verticalRulerView as! LineNumberRulerView).refresh()
    }
}

