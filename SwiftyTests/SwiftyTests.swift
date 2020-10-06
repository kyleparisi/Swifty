import XCTest

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
    
    func testJSSyntax() throws {
        LANGUAGE = "js"
        keyDown(view: view, string: "var")
        var range = NSRange(location: 0, length: view.textStorage!.length)
        let color = view.textStorage?.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: &range) as! NSColor
        XCTAssertEqual("#" + color.toHex!, "#8BE9FE")
    }
    
    func testGoSyntax() throws {
        LANGUAGE = "go"
        keyDown(view: view, string: "func")
        var range = NSRange(location: 0, length: view.textStorage!.length)
        let color = view.textStorage?.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: &range) as! NSColor
        XCTAssertEqual("#" + color.toHex!, "#8BE9FE")
    }
    
    func testDeleteLine() throws {
        keyDown(view: view, string: "abc")
        XCTAssertEqual(view.selectedRange().location, 3)
        view.keyDown(with: cmd_delete()!)
        XCTAssertEqual(view.selectedRange().location, 0)
        XCTAssertEqual(view.textStorage?.string, "")
    }
}
