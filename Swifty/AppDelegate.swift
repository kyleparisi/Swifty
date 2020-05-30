//
//  AppDelegate.swift
//  Swifty
//
//  Created by Kyle Parisi on 5/27/20.
//  Copyright © 2020 Kyle Parisi. All rights reserved.
//

import Cocoa
import SwiftUI
import Nautilus

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

//        for _ in 0...100000 {
//            let escapedptr = "<div>Kyle</div>".withCString(escape_html)
//            let test = "test"
//            escape_html(test.cString(using: String.Encoding.utf8))
//            let escaped = String(bytesNoCopy: escapedptr!, length: strlen(escapedptr!), encoding: .utf8, freeWhenDone: true)
//            print(escaped)
//        }
        
//        var content = "".cString(using: .utf8)
//        var contentptr = UnsafeMutablePointer(mutating: content)
        for _ in 0...100000 {
            let ptr = highlight("", "go", "html", "monokai")
            print(ptr)
            let test = String(cString: ptr.r0)
            free(ptr.r0)
            free(ptr.r1)
            print(test)
        }

        // Create the window and set the content view. 
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

