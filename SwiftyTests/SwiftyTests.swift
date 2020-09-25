//
//  SwiftyTests.swift
//  SwiftyTests
//
//  Created by Kyle Parisi on 9/19/20.
//  Copyright © 2020 Kyle Parisi. All rights reserved.
//

import XCTest

func keypress(key: String) -> NSEvent? {
    return NSEvent.keyEvent(with: .keyDown, location: NSPoint(), modifierFlags: NSEvent.ModifierFlags(rawValue: 256), timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)
}

class SwiftyTests: XCTestCase {
    var view = MyTextView()

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let storyboard = NSStoryboard(name: "Main", bundle: bundle)
        let viewController = storyboard.instantiateController(withIdentifier: "ViewController") as! MyViewContoller
        NSApplication.shared.keyWindow?.contentViewController = viewController
        _ = viewController.view
        view = viewController.textView!
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBasic() throws {
        XCTAssertEqual(view.textStorage?.string, "")
        view.keyDown(with: keypress(key: "a")!)
        XCTAssertEqual(view.textStorage?.string, "a")
    }
}
