//
//  FileEvent.swift
//  DEKit
//
//  Created by Kirill Gorbachyonok on 5/3/20.
//

import Foundation

struct FileEvent {
    let fileName: String
    let fileURL: URL
    let type: EventType
    let checksum: String?
    let when = Date().string
}

extension FileEvent {
    enum EventType {
        case write
        case delete
        case renamed(oldName: String)
        case moved(oldURL: URL)
        case newFile
        case error
    }
}

extension FileEvent: CustomStringConvertible {
    var description: String {
        switch type {
        case .write:
            return """
            
            🔔 WRITE at \(when)
                📄 filename: \(fileName)
                📁 location: \(fileURL.path)
                🧮 checksum: \(checksum!)
            """
        case .delete:
            return """
            
            🔔 DELETE at \(when)
                📄 filename: \(fileName)
                📁 location: \(fileURL.path)
            """
        case .renamed(let oldName):
            return """
            
            🔔 RENAMED at \(when)
                📄 old filename: \(oldName)
                🆕 new filename: \(fileName)
                📁 location: \(fileURL.path)
                🧮 checksum: \(checksum!)
            """
        case .moved(let oldLocation):
            return """
            
            🔔 MOVED at \(when)
                📄 filename: \(fileName)
                📁 old location: \(oldLocation.path)
                🆕 new location: \(fileURL.path)
            """
        case .newFile:
            return """
            
            🔔 NEW FILE at \(when)
                📄 filename: \(fileName)
                📁 location: \(fileURL.path)
                🧮 checksum: \(checksum!)
            """
        case .error:
            return ""
        }
    }
}
