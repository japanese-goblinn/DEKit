import Foundation

do {
    try DirectoryEvents(watch: "Downloads/DEKitTest") { print($0) }
} catch  {
    print(error.localizedDescription)
}

RunLoop.current.run()
