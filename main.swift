import Foundation

do {
    try DirectoryEvents(watch: "Downloads/DEKitTest")
} catch  {
    print(error.localizedDescription)
}

RunLoop.current.run()
