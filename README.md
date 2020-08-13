# DEKit

Library to watch changes in directory

```swift
do {
    // you can ignore value and receive notifications, but DirectoryEvents object will be destroyed only if directory deleted
    try DirectoryEvents(watch: "Downloads/DEKitTest")

    // you can pass a custom clousure to process received events as you wish (by default prints all info)
    try DirectoryEvents(watch: "Downloads/DEKitTest") { event in
        print(event.when)
    }

    let de = try DirectoryEvents(watch: "Downloads/DEKitTest")
    de.stopReceiving() // call this method to explicitly finish watching directory and destroy DirectoryEvents object
} catch {
    print(error.localizedDescription)
}
```

With this code

```swift
do {
    try DirectoryEvents(watch: "Downloads/DEKitTest")
} catch {
    print(error.localizedDescription)
}
```

you will receive this output

![ouput](./out.png)

## Installation

### `macOS` app

In Xcode go to `File -> Swift Packages -> Add Package Dependency` and paste in the repo's url: `https://github.com/japanese-goblinn/DEKit.git`

### `Swift Package`

```swift
let package = Package(
    name: "Package",
    dependencies: [
        .package(url: "https://github.com/japanese-goblinn/DEKit.git", from: "1.2")
    ],
    targets: [
        .target(
            name: "Package",
            dependencies: ["DEKit"])
    ]
)
```

## Requirments

Please add read permissions for folders that you want to watch in `.entitlements` file

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<!--This permission is needed to ask for read only once-->
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
<!--All permissions below is for specific directories from which you want ot read. Add more premissions here if you want to read not only from Downloads folder-->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.files.downloads.read-only</key>
<true/>
```
