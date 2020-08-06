import Foundation

do {
    // you can ignore value and receive notifications, but DirectoryEvents object will be destroyed only if directory deleted
    try DirectoryEvents(watch: "Downloads/DEKitTest")

    // you can pass a custom clousure to process received events as you wish
    try DirectoryEvents(watch: "Downloads/DEKitTest") { event in
        print(event.when)
    }

    let de = try DirectoryEvents(watch: "Downloads/DEKitTest")
    de.stopReceiving() // call this method to explicitly finish watching directory and destroy DirectoryEvents object
} catch  {
    print(error.localizedDescription)
}

RunLoop.current.run()
