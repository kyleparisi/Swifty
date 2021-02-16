import Cocoa

class Document: NSDocument {
    
    @objc var content = Content(contentString: "")
    var contentViewController: MyViewContoller!
    var lastRead: Date?
    
    // MARK: - Enablers
    
    // This enables auto save.
    override class var autosavesInPlace: Bool {
        return true
    }
    
    // This enables asynchronous-writing.
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    // This enables asynchronous reading.
    override class func canConcurrentlyReadDocuments(ofType: String) -> Bool {
        return ofType == "public.plain-text"
    }
    
    // MARK: - User Interface
    
    /// - Tag: makeWindowControllersExample
    override func makeWindowControllers() {
        Swift.print(fileURL!.pathExtension)
        LANGUAGE = fileURL!.pathExtension
        
        // Returns the storyboard that contains your document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        if let windowController =
            storyboard.instantiateController(
                withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as? NSWindowController {
            addWindowController(windowController)
            
            // Set the view controller's represented object as your document.
            if let contentVC = windowController.contentViewController as? MyViewContoller {
                contentVC.representedObject = content
                contentViewController = contentVC
            }
        }
    }
    
    // MARK: - Reading and Writing
    
    /// - Tag: readExample
    override func read(from data: Data, ofType typeName: String) throws {
        content.read(from: data)
        lastRead = fileModificationDate
    }
    
    /// - Tag: writeExample
    override func data(ofType typeName: String) throws -> Data {
        return content.data()!
    }
    
    // Another application modified the file
    override func presentedItemDidChange() {
        let attr = try! FileManager.default.attributesOfItem(atPath: fileURL!.path)
        let modified = attr[.modificationDate] as! Date
        if (lastRead == modified) {
            // file not modified from last we've read
            return
        }

        // file modified, read again from main event loop
        DispatchQueue.main.async { [weak self] in
            guard let doc = self else {
                return
            }
            try? doc.read(from: doc.fileURL!, ofType: doc.fileType!)
            doc.lastRead = modified
        }
    }
}
