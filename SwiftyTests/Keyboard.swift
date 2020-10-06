import AppKit

func keypress(key: String) -> NSEvent? {
    return NSEvent.keyEvent(with: .keyDown, location: NSPoint(), modifierFlags: NSEvent.ModifierFlags(rawValue: 256), timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: Keycodes[key]!)
}

func keyDown(view: NSView, string: String) {
    for key in string {
        view.keyDown(with: keypress(key: String(key))!)
    }
}

func cmd_delete() -> NSEvent? {
    return NSEvent.keyEvent(with: .keyDown, location: NSPoint(), modifierFlags: .command, timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: String(format: "%c", Keycodes.backspace), charactersIgnoringModifiers: String(format: "%c", Keycodes.backspace), isARepeat: false, keyCode: 51)
}
