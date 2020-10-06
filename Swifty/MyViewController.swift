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
            for _ in 3 ... 6 {
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
    
    var toHex: String? {
        return toHex()
    }

    // MARK: - From NSColor to String

    func toHex(alpha: Bool = false) -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if alpha {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
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
var LANGUAGE = "js"

var insertionLocations: Set<Int> = []

class MyViewContoller: NSViewController {
    @IBOutlet var textView: MyTextView?
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
        // print(test)
        free(ptr.r0)
        free(ptr.r1)
        let terms: [Term] = try! JSONDecoder().decode([Term].self, from: test.data(using: .utf8)!)
        var location = 0
        for term in terms {
            var range = NSRange(location: location, length: term.value.count)
            // make sure we're still in bounds. adding attributes to the trailing new line breaks things
            if range.upperBound > string.count {
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
    var currentLineColor: NSColor?

    override func awakeFromNib() {
        layoutManager?.replaceTextStorage(MyTextStorage())

        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false

        // gutter
        enclosingScrollView?.verticalRulerView = LineNumberRulerView(textView: self)
        enclosingScrollView?.hasHorizontalRuler = false
        enclosingScrollView?.hasVerticalRuler = true
        enclosingScrollView?.rulersVisible = true

        // initlialize the theme
        let ptr = colors(THEME)
        let fg = String(cString: ptr.fg)
        let bg = String(cString: ptr.bg)
        textColor = NSColor(hex: fg)
        backgroundColor = NSColor(hex: bg)
        insertionPointColor = NSColor(hex: fg)
        currentLineColor = NSColor(hex: bg).highlight(withLevel: 0.05)
        free(ptr.fg)
        free(ptr.bg)

        typingAttributes = [.font: NSFont(name: "Hack-Regular", size: 14.0)!]
    }

    override public var drawsBackground: Bool {
        set {} // always return false, we'll draw the background
        get { return false }
    }

    override public func draw(_ dirtyRect: NSRect) {
        // I don't know why this is needed but without it the cursor blink off color will the background color
        // and not the selected line color.  It might have to do with drawBackground: above.
        backgroundColor = backgroundColor

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(backgroundColor.cgColor)
        context.fill(dirtyRect)

        var selectedLineRect: NSRect?
        guard let layout = layoutManager,
            let container = textContainer else { return }

        if selectedRange().length > 0 {
            selectedLineRect = nil
        } else {
            selectedLineRect = layout.boundingRect(forGlyphRange: selectedRange(), in: container)
        }

        if let textRect = selectedLineRect {
            let lineRect = NSRect(x: 0, y: textRect.origin.y, width: dirtyRect.width, height: textRect.height)
            context.setFillColor(currentLineColor!.cgColor)
            context.fill(lineRect)
        }

        super.draw(dirtyRect)

        (enclosingScrollView?.verticalRulerView as! LineNumberRulerView).refresh()
    }

    override func insertNewline(_ sender: Any?) {
        super.insertNewline(sender)

        let range = selectedRange()
        let cursor = range.location
        guard cursor != NSNotFound else { return }

        let content = string as NSString

        let currentLineRange = content.lineRange(for: NSRange(location: cursor, length: 0))
        let previousLineRange = content.lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
        let previousLineText = content.substring(with: previousLineRange)

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
            case " ": return (count: info.count + 1, stop: false, last: info.last)
            case "\t": return (count: info.count + 4, stop: false, last: info.last)
            default: return (count: info.count, stop: true, last: info.last)
            }
        }

        // find the last-non-whitespace char
        var spaceCount = indent.count

        switch indent.last {
        case "{": spaceCount += 4
        case "}": spaceCount -= 4; if spaceCount < 0 { spaceCount = 0 }
        default: break
        }

        // insert the new indent
        let start = NSRange(location: currentLineRange.location, length: 0)
        let spaces = String(repeating: " ", count: spaceCount)
        if nextCharacter() == "}" {
            // put } on new line first
            super.insertText("\n", replacementRange: start)
            setSelectedRange(NSRange(location: selectedRange().location - 1, length: 0))
        }
        super.insertText(spaces, replacementRange: start)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // draw current insertion point
        super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)

        if insertionLocations.isEmpty {
            return
        }

        for insertionLocation in insertionLocations {
            // remove overlapping insertion
            if selectedRange.location == insertionLocation {
                insertionLocations.remove(insertionLocation)
                return
            }

            let glyphIndex = layoutManager?.glyphIndexForCharacter(at: insertionLocation)
            let arect = layoutManager?.boundingRect(forGlyphRange: NSRange(location: glyphIndex!, length: 0), in: textContainer!).offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            let newRect = NSRect(x: arect!.minX, y: arect!.minY, width: 1, height: arect!.height)
            super.drawInsertionPoint(in: newRect, color: color, turnedOn: flag)
        }
    }

    func nextCharacter() -> String? {
        let range = selectedRange()
        let cursor = range.location
        guard cursor != NSNotFound else { return nil }
        let content = string as NSString
        let currentLineRange = content.lineRange(for: NSRange(location: cursor, length: 0))
        let lineEnd = currentLineRange.upperBound
        if cursor < lineEnd {
            let nextChar = content.substring(with: NSRange(location: cursor, length: 1))
            return nextChar
        }
        return nil
    }

    override func keyDown(with event: NSEvent) {
        print(event)
        let modifierFlags = event.modifierFlags
        let Escape = 53
        if event.keyCode == Escape {
            insertionLocations = []
            setSelectedRange(NSRange(location: selectedRange().location, length: 0), affinity: .upstream, stillSelecting: false)
        }

        let DownArrow = 125
        if event.keyCode == DownArrow, modifierFlags.contains(NSEvent.ModifierFlags.command) {
            print("do thing")
            insertionLocations.insert(0)
        }

        interpretKeyEvents([event])
    }

    override func moveLeft(_ sender: Any?) {
        super.moveLeft(sender)

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let location = max(insertionLocation - 1, 0)
            newInsertionLocations.insert(location)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveRight(_ sender: Any?) {
        super.moveRight(sender)

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let location = insertionLocation + 1
            newInsertionLocations.insert(location)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveRightAndModifySelection(_: Any?) {
        // insertion locations are in selection mode
        if selectedRanges.count > 1 {
            var ranges: [NSValue] = []
            for selected in selectedRanges {
                let range = selected.rangeValue
                ranges.append(NSValue(range: NSRange(location: range.location, length: range.length + 1)))
            }
            setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)
            for insertionLocation in insertionLocations {
                // remove overlapping insertion
                if selectedRange.location == insertionLocation {
                    insertionLocations.remove(insertionLocation)
                    return
                }

                let glyphIndex = layoutManager?.glyphIndexForCharacter(at: insertionLocation)
                let arect = layoutManager?.boundingRect(forGlyphRange: NSRange(location: glyphIndex!, length: 0), in: textContainer!).offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                let newRect = NSRect(x: arect!.minX, y: arect!.minY, width: 1, height: arect!.height)
                super.drawInsertionPoint(in: newRect, color: insertionPointColor, turnedOn: true)
            }
            return
        }

        // new selection mode
        let currentRange = selectedRange()
        var ranges: [NSValue] = [NSValue(range: NSRange(location: currentRange.location, length: currentRange.length + 1))]
        for insertionLocation in insertionLocations {
            ranges.append(NSValue(range: NSRange(location: insertionLocation, length: currentRange.length + 1)))
        }
        print("ranges", ranges)
        setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)
    }

    override func moveWordRight(_ sender: Any?) {
        super.moveWordRight(sender)

        guard let textStorage = textStorage else {
            return
        }

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let location = textStorage.nextWord(from: insertionLocation, forward: true)
            newInsertionLocations.insert(location)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveWordLeft(_ sender: Any?) {
        super.moveWordLeft(sender)

        guard let textStorage = textStorage else {
            return
        }

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let location = textStorage.nextWord(from: insertionLocation, forward: false)
            newInsertionLocations.insert(location)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveLeftAndModifySelection(_: Any?) {
        // insertion locations are in selection mode
        if selectedRanges.count > 1 {
            var ranges: [NSValue] = []
            for selected in selectedRanges {
                let range = selected.rangeValue
                ranges.append(NSValue(range: NSRange(location: max(range.location - 1, 0), length: range.length + 1)))
            }
            setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)
            return
        }

        // new selection mode
        let currentRange = selectedRange()
        let length = currentRange.length + 1
        var ranges: [NSValue] = [NSValue(range: NSRange(location: max(currentRange.location - 1, 0), length: length))]
        for insertionLocation in insertionLocations {
            ranges.append(NSValue(range: NSRange(location: max(insertionLocation - 1, 0), length: length)))
        }
        print("ranges", ranges)
        setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)
    }

    override func moveToBeginningOfLine(_ sender: Any?) {
        super.moveToBeginningOfLine(sender)

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let content = string as NSString
            let currentLineRange = content.lineRange(for: NSRange(location: insertionLocation, length: 0))
            newInsertionLocations.insert(currentLineRange.lowerBound)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveToBeginningOfLineAndModifySelection(_: Any?) {
        let content = string as NSString
        let range = selectedRange()
        let currentLineRange = content.lineRange(for: range)
        // adjust line range upper bound down 1 to ignore new line
        let lineRange = NSRange(location: currentLineRange.lowerBound, length: currentLineRange.upperBound - 1)
        var ranges: [NSValue] = [NSValue(range: lineRange)]

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let currentLineRange = content.lineRange(for: NSRange(location: insertionLocation, length: 0))
            newInsertionLocations.insert(currentLineRange.lowerBound)
            // adjust line range upper bound down 1 to ignore new line
            let lineRange = NSRange(location: currentLineRange.lowerBound, length: currentLineRange.upperBound - 1)
            ranges.append(NSValue(range: lineRange))
        }
        setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)

        insertionLocations = newInsertionLocations
    }

    override func moveToEndOfLine(_ sender: Any?) {
        super.moveToEndOfLine(sender)

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let content = string as NSString
            let currentLineRange = content.lineRange(for: NSRange(location: insertionLocation, length: 0))
            newInsertionLocations.insert(currentLineRange.upperBound - 1)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveToEndOfLineAndModifySelection(_: Any?) {
        let content = string as NSString
        let range = selectedRange()
        let currentLineRange = content.lineRange(for: range)
        // adjust line range upper bound down 1 to ignore new line
        let lineRange = NSRange(location: currentLineRange.lowerBound, length: currentLineRange.upperBound - 1)
        var ranges: [NSValue] = [NSValue(range: lineRange)]

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let currentLineRange = content.lineRange(for: NSRange(location: insertionLocation, length: 0))
            newInsertionLocations.insert(currentLineRange.lowerBound)
            // adjust line range upper bound down 1 to ignore new line
            let lineRange = NSRange(location: currentLineRange.lowerBound, length: currentLineRange.upperBound - 1)
            ranges.append(NSValue(range: lineRange))
        }
        setSelectedRanges(ranges, affinity: .upstream, stillSelecting: false)

        insertionLocations = newInsertionLocations
    }

    override func moveUp(_ sender: Any?) {
        super.moveUp(sender)

        guard
            let layoutManager = layoutManager,
            let textContainer = textContainer
        else {
            return
        }

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            // find the glyph location and move just above it's rect,
            // ask for the location of the glyph at that point
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: insertionLocation)
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 0), in: textContainer).offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            let point = NSPoint(x: rect.minX, y: rect.maxY - 1)
            let index = characterIndexForInsertion(at: point)
            newInsertionLocations.insert(index)
        }
        insertionLocations = newInsertionLocations
    }

    override func moveDown(_ sender: Any?) {
        super.moveDown(sender)

        guard
            let layoutManager = layoutManager,
            let textContainer = textContainer
        else {
            return
        }

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            // find the glyph location and move just below it's rect,
            // ask for the location of the glyph at that point
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: insertionLocation)
            let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 0), in: textContainer).offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
            let point = NSPoint(x: rect.minX, y: rect.maxY + 1)
            let index = characterIndexForInsertion(at: point)
            newInsertionLocations.insert(index)
        }
        insertionLocations = newInsertionLocations
    }

    override func deleteBackward(_ sender: Any?) {
        if string.count == 0 {
            return
        }

        print("delete backward")
        print(selectedRanges)

        // insertion locations are in selection mode
        if selectedRange().length > 1 {
            for range in selectedRanges.reversed() {
                if range.rangeValue.length == 0 {
                    replaceCharacters(in: NSRange(location: max(range.rangeValue.location - 1, 0), length: 1), with: "")
                } else {
                    replaceCharacters(in: range.rangeValue, with: "")
                }
            }

            return
        }

        super.deleteBackward(sender)

        var newInsertionLocations: Set<Int> = []
        for insertionLocation in insertionLocations {
            let location = max(insertionLocation - 1, 0)
            replaceCharacters(in: NSRange(location: location, length: 1), with: "")
            newInsertionLocations.insert(location)
        }
        insertionLocations = newInsertionLocations
    }

    override func deleteForward(_: Any?) {
        for range in selectedRanges.reversed() {
            print(range)
            if range.rangeValue.length == 0 {
                replaceCharacters(in: NSRange(location: range.rangeValue.location, length: 1), with: "")
            } else {
                replaceCharacters(in: range.rangeValue, with: "")
            }
        }
//        super.deleteForward(sender)

//        for insertionLocation in insertionLocations {
//            super.insertText("", replacementRange: NSRange(location: insertionLocation, length: 1))
//        }
    }

    override func deleteToBeginningOfLine(_ sender: Any?) {
        print("delete line")
        super.deleteToBeginningOfLine(sender)

        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            let content = string as NSString
            let currentLineRange = content.lineRange(for: NSRange(location: insertionLocation, length: 0))
            // keep line intact with \n
            super.insertText("\n", replacementRange: currentLineRange)
            newInsertionLocations.insert(currentLineRange.lowerBound)
        }
        insertionLocations = newInsertionLocations
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let string = string as! String

        let jumpChars = ["}", ")", "\"", "'", "]"]
        if jumpChars.contains(string), jumpChars.contains(nextCharacter() ?? "") {
            setSelectedRange(NSRange(location: selectedRange().location + 1, length: 0))
            return
        }

        super.insertText(string, replacementRange: replacementRange)

        if string.count != 1 {
            return
        }

        // auto complete {("'[
        var matched = true
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
            matched = false
        }
        // go back 1 position because of the auto complete
        if matched {
            setSelectedRange(NSRange(location: selectedRange().location - 1, length: 0))
        }

        // handle multiple insertion locations
        if insertionLocations.isEmpty {
            return
        }
        var newInsertionLocations: Set<Int> = Set()
        for insertionLocation in insertionLocations {
            super.insertText(string, replacementRange: NSRange(location: insertionLocation, length: 0))
            newInsertionLocations.insert(insertionLocation + 1)
        }
        insertionLocations = newInsertionLocations
    }
}
