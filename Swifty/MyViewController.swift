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
    let bold: Int
    let italic: Int
    let underline: Int
}

struct Term: Decodable {
    let type: String
    let value: String
    let style: Style
}

typealias IndentInfo = (count: Int, stop: Bool, last: Character)

let THEME = "dracula"
let LANGUAGE = "js"

class MyViewController: NSViewController {
    @IBOutlet var text: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        
        // initlialize the theme
        let ptr = colors(THEME)
        let fg = String(cString: ptr.fg)
        let bg = String(cString: ptr.bg)
        text.textColor = NSColor(hex: fg)
        text.backgroundColor = NSColor(hex: bg)
        text.insertionPointColor = NSColor(hex: fg)
        free(ptr.fg)
        free(ptr.bg)
        
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
        let ptr = highlight(string, LANGUAGE, THEME)
        let test = String(cString: ptr.r0)
        print(test)
        free(ptr.r0)
        free(ptr.r1)
        let terms: [Term] = try! JSONDecoder().decode([Term].self, from: test.data(using: .utf8)!)
        var location = 0
        for term in terms {
            var range = NSRange(location: location, length: term.value.count)
            // make sure we're still in bounds. adding attributes to the trailing new line breaks things
            if (range.upperBound > string.count) {
                range = NSRange(location: location, length: term.value.count - 1)
            }
            addAttributes([.foregroundColor: NSColor(rgbValue: term.style.color)], range: range)
            if term.style.bold == 1 {
                let fontManager = NSFontManager.shared
                let newFont = fontManager.convert(font!, toHaveTrait: .boldFontMask)
                addAttributes([.font: newFont], range: range)
            }
            if term.style.italic == 1 {
                let fontManager = NSFontManager.shared
                let newFont = fontManager.convert(font!, toHaveTrait: .italicFontMask)
                addAttributes([.font: newFont], range: range)
            }
            if term.style.underline == 1 {
                addAttributes([.underlineStyle: 1], range: range)
            }
            location += term.value.count
        }

    }
}

class MyTextView: NSTextView {
    override func awakeFromNib() {
        layoutManager?.replaceTextStorage(MyTextStorage())
        backgroundColor = NSColor(hex: "#fff")
        textColor = NSColor(hex: "#fff")
        insertionPointColor = NSColor(hex: "#000")
        // gutter
        enclosingScrollView?.verticalRulerView = LineNumberRulerView(textView: self)
        enclosingScrollView?.hasHorizontalRuler = false
        enclosingScrollView?.hasVerticalRuler = true
        enclosingScrollView?.rulersVisible = true
        
        typingAttributes = [.font: NSFont(name: "Hack-Regular", size: 14.0)!]
    }
    
    override func insertNewline(_ sender: Any?) {
        super.insertNewline(sender)
        
        let range  = self.selectedRange()
        let cursor = range.location
        guard cursor != NSNotFound else { return }
        
        let content = self.string as NSString
        
        let currentLineRange  = content.lineRange(for: NSRange(location: cursor, length: 0))
        let previousLineRange = content.lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
        let previousLineText  = content.substring(with: previousLineRange)
  
        let indentInfo = (count: 0, stop: false, last: Character(" "))
        let indent = previousLineText.reduce(indentInfo) { (info: IndentInfo, char) -> IndentInfo in
            guard info.stop == false
            else {
                // remember the last non-whitespace char
                if char == " " || char == "\t" || char == "\n" {
                    return info
                } else {
                    return (count: info.count, stop: info.stop, last: char)
                }
            }
            switch char {
            case " " : return (stop: false, count: info.count + 1,      last: info.last)
            case "\t": return (stop: false, count: info.count + 4, last: info.last)
            default  : return (stop: true , count: info.count,          last: info.last)
            }
        }
        
        // find the last-non-whitespace char
        var spaceCount = indent.count
        
        switch indent.last {
        case "{": spaceCount += 4
        case "}": spaceCount -= 4; if spaceCount < 0 { spaceCount = 0 }
        default : break
        }
        
        // insert the new indent
        let start  = NSRange(location: currentLineRange.location, length: 0)
        let spaces = String(repeating: " ", count: spaceCount)
        if nextCharacter() == "}" {
            // put } on new line first
            super.insertText("\n", replacementRange: start)
            setSelectedRange(NSRange(location: selectedRange().location - 1, length: 0))
        }
        super.insertText(spaces, replacementRange: start)
    }
    
    func nextCharacter() -> String? {
        let range  = self.selectedRange()
        let cursor = range.location
        guard cursor != NSNotFound else { return nil }
        let content = self.string as NSString
        let currentLineRange  = content.lineRange(for: NSRange(location: cursor, length: 0))
        let lineEnd = currentLineRange.upperBound
        if (cursor < lineEnd) {
            let nextChar = content.substring(with: NSRange(location: cursor, length: 1))
            return nextChar
        }
        return nil
    }
    
    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags
        let Delete = 51
        if event.keyCode == Delete && modifierFlags.contains(NSEvent.ModifierFlags.command) {
            let range  = self.selectedRange()
            let cursor = range.location
            guard cursor != NSNotFound else { return }
            let content = self.string as NSString
            let currentLineRange  = content.lineRange(for: NSRange(location: cursor, length: 0))
            setSelectedRange(currentLineRange)
        }
        super.keyDown(with: event)
    }
    
    override func insertText(_ string: Any, replacementRange: NSRange) {
        
        let string = string as! String
        
        let jumpChars = ["}", ")", "\"", "'", "]"]
        if (jumpChars.contains(string) && jumpChars.contains(nextCharacter() ?? "")) {
            setSelectedRange(NSRange(location: selectedRange().location + 1, length: 0))
            return
        }
        
        super.insertText(string, replacementRange: replacementRange)
        
        if string.count != 1 {
            return
        }
        switch string[string.startIndex] {
        case "{":
            super.insertText("}", replacementRange: replacementRange)
        case "(":
            super.insertText(")", replacementRange: replacementRange)
        case "\"":
            super.insertText("\"", replacementRange: replacementRange)
        case "'":
            super.insertText("'", replacementRange: replacementRange)
        case "[":
            super.insertText("]", replacementRange: replacementRange)
        default:
            return
        }
        setSelectedRange(NSRange(location: selectedRange().location - 1, length: 0))
    }

    override func didChangeText() {
        (enclosingScrollView?.verticalRulerView as! LineNumberRulerView).refresh()
    }
}

