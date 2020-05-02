import Foundation
import CommonCrypto

extension String: Error {}

extension String: LocalizedError {
    public var errorDescription: String? { self }
}

extension Date {
    var string: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        return dateFormatter.string(from: self)
    }
}

extension Data {
    public var SHA256hash: Self {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Self(hash)
    }
    
    public var SHA256hashString: String {
        self.SHA256hash.map { String(format: "%02X", $0) }.joined()
    }
}

struct FileEvent {
    let fileName: String
    let fileURL: URL
    let type: EventType
    let checksum: String?
    let when = Date().string
}

extension FileEvent {
    enum EventType: String {
        case write
        case delete
        case renamed
        case moved
        case error
    }
}

extension FileEvent: CustomStringConvertible {
    var description: String {
        """
        
        🔔 Notification at \(when)
        
        📄 file: \(fileName)
        📁 location: \(fileURL.path)
        🚩 types: \(type)
        \(checksum != nil ? "🧮 checksum: \(checksum!)" : "")
        """
    }
}

struct FilterFlag: OptionSet {
    
    let rawValue: RawValue
    
    static let error = FilterFlag([])
    static let write = FilterFlag(rawValue: UInt32(NOTE_WRITE))
    static let delete = FilterFlag(rawValue: UInt32(NOTE_DELETE))
    static let rename = FilterFlag(rawValue: UInt32(NOTE_RENAME))
    
    static let all: FilterFlag = [.write, .delete, .rename]
}

extension FilterFlag {
    typealias RawValue = UInt32
}

public class DirectoryEvents {

    private let events = DispatchQueue(label: "com.japanese-goblinn.\(#function).\(UUID())")
    
    private var watchedFiles = [FileDescriptor: URL]()
    
    private lazy var fileManager = FileManager.default
    
    private var kernelQueue: Int32
    
    private var watchedDirectory: FileDescriptor = -1
    
    private let handler: (FileEvent) -> Void
    
    @discardableResult
    init(watch directoryPath: Path, with handler: @escaping (FileEvent) -> Void) throws {
        self.handler = handler
        kernelQueue = kqueue()
        guard kernelQueue >= 0 else { throw "⛔️ Failed to create kernel queue" }
        try watchDirectory(at: directoryPath)
    }

    deinit {
        close(kernelQueue)
        closeWatched()
    }
    
    private func closeWatched() {
        watchedFiles.keys.forEach { close($0) }
        close(watchedDirectory)
    }
    
    public func watchDirectory(at path: Path) throws {
        closeWatched()
        watchedFiles.removeAll()
        let directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
        guard isDirectory(directoryURL) else { throw "⛔️ Not a directory" }
        let descriptor = openForEventsAndGetDescriptor(at: directoryURL)
        guard descriptor > 0 else { throw "⛔️ Directory not found" }
        watchedDirectory = descriptor
        try startReceivingChanges(at: directoryURL)
    }
    
    private func startReceivingChanges(at directory: URL) throws {
        try fileManager.contentsOfDirectory(atPath: directory.path).forEach {
            watchEvents(at: directory.appendingPathComponent($0))
        }
    }
    
    private func openForEventsAndGetDescriptor(at pathURL: URL) -> FileDescriptor {
        let descriptor = open(fileManager.fileSystemRepresentation(withPath: pathURL.path), O_EVTONLY)
        return descriptor
    }
        
    private func watchEvents(at pathURL: URL) {
        let fileDescriptor = openForEventsAndGetDescriptor(at: pathURL)
        guard fileDescriptor > 0 else {
            print("⛔️ \(pathURL.lastPathComponent) can't be watched due to internal error")
            return
        }
        createEventAtKernelQueue(from: fileDescriptor)
        watchedFiles[fileDescriptor] = pathURL
        events.async(execute: fileEventsWatcher)
        print("👁 \(pathURL.lastPathComponent) is now watched...")
    }
    
    private func createEventAtKernelQueue(from descriptor: FileDescriptor) {
        var queueEvent = kevent(
            ident: UInt(descriptor),
            filter: Int16(EVFILT_VNODE),
            flags: UInt16(EV_ADD | EV_CLEAR),
            fflags: FilterFlag.all.rawValue,
            data: 0,
            udata: nil
        )
        kevent(kernelQueue, &queueEvent, 1, nil, 0, nil)
    }
        
    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return fileExists && isDirectory.boolValue
    }
    
    private func pathURL(for descriptor: FileDescriptor) -> URL {
        var buffer = [CChar](repeating: 0, count: 100)
        _ = fcntl(descriptor, F_GETPATH, &buffer)
        return URL(fileURLWithPath: String(cString: buffer))
    }
    
    private func fileEventsWatcher() {
        var event = kevent()
        var timeout = timespec(tv_sec: 1, tv_nsec: 0)
        while true {
            let amountOfEvents = kevent(kernelQueue, nil, 0, &event, 1, &timeout)
            guard amountOfEvents > 0 && event.filter == EVFILT_VNODE && event.fflags > 0
                else { continue }
            let flag = handleResult(of: event)
            guard flag.contains(.delete) else { continue }
            let fileDescriptor = FileDescriptor(event.ident)
            close(fileDescriptor)
            watchedFiles[fileDescriptor] = nil
            break
        }
    }
    
    private func calculateChecksum(_ checksum: inout String?, of fileURL: URL) {
        if let fileData = try? Data(contentsOf: fileURL) {
            checksum = fileData.SHA256hashString
        }
    }
    
    private func handleResult(of event: kevent) -> FilterFlag {
        
        let descriptor = FileDescriptor(event.ident)
        let flag = FilterFlag(rawValue: UInt32(event.fflags))
        
        if descriptor == watchedDirectory {
            return flag
        }
        
        guard var fileURL = watchedFiles[descriptor] else { return .error }
        
        var checksum: String?
        var eventType: FileEvent.EventType = .error
            
        if flag.contains(.delete) {
            eventType = .delete
        }
        if flag.contains(.rename) {
            let newFileURL = pathURL(for: descriptor)
            if newFileURL == fileURL {
                eventType = .renamed
            } else {
                eventType = .moved
                watchedFiles[descriptor] = newFileURL
                fileURL = newFileURL
            }
            calculateChecksum(&checksum, of: fileURL)
        }
        if flag.contains(.write) {
            eventType = .write
            calculateChecksum(&checksum, of: fileURL)
        }
        handler(
            FileEvent(
                fileName: fileURL.lastPathComponent,
                fileURL: fileURL,
                type: eventType,
                checksum: checksum
            )
        )
        return flag
    }
    
}

public extension DirectoryEvents {
    typealias Path = String
    typealias FileDescriptor = Int32
}

do {
    try DirectoryEvents(watch: "Downloads/DEKitTest") { print($0) }
} catch  {
    print(error.localizedDescription)
}

RunLoop.current.run()
