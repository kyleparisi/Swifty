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
    convenience init?(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count != 6 {
            return nil
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
}

let STYLE = "github"

struct Token: Decodable {
    let type: String
    let value: String
}

struct Xcode {
    let CommentSingle = "#177500"
    let CommentPreproc = "#633820"
}
let xcode = Xcode()

class WebViewController: NSViewController {
    @IBOutlet var text: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let colorsptr = colors(STYLE)
//        print(colorsptr)
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
        let str = str.replacingOccurrences(of: "\t", with: " ")
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
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
        if (self.editedRange.location == 0 && self.editedRange.length == 0) {
            return
        }
        let highlighted = highlight(self.string, "go", STYLE)
        let tokensString = String(cString: highlighted.r0)
        free(highlighted.r0)
        free(highlighted.r1)
        let tokens: [Token] = try! JSONDecoder().decode([Token].self, from: tokensString.data(using: .utf8)!)
        var location = 0, length = 0
        for token in tokens {
            length = token.value.count
            defer { location += length; length = 0 }
            print(token, location, length)
            if token.type == "KeywordDeclaration" {
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(hex: "#00cd00")!,
                ]
                self.setAttributes(attributes, range: NSRange(location: location, length: length))
                continue
            }
            if token.type == "CommentSingle" {
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(hex: xcode.CommentSingle)!,
                ]
                self.setAttributes(attributes, range: NSRange(location: location, length: length))
                continue
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(hex: "#000000")!,
            ]
            self.setAttributes(attributes, range: NSRange(location: location, length: length))
        }
    }
}

class MyTextView: NSTextView {
    override func awakeFromNib() {
        layoutManager?.replaceTextStorage(MyTextStorage())
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

