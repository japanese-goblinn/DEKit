//
//  DirectoryEvents.swift
//  DEKit
//
//  Created by Kirill Gorbachyonok on 5/3/20.
//

import Foundation

// MARK: - Typealiases
public extension DirectoryEvents {
    typealias Path = String
    typealias FileDescriptor = Int32
}

// MARK: - API
public extension DirectoryEvents {
    func watchAnotherDirectory(at newDirectoryPath: Path) throws {
        try watchDirectory(at: newDirectoryPath)
    }
    
    func stopReceiving() {
        deinitNeeded = true
    }
}

public class DirectoryEvents {

    private let events = DispatchQueue(label: "com.japanese-goblinn.\(#function).\(UUID())")
    
    private var watchedFiles = [FileDescriptor: URL]()
    
    private lazy var fileManager = FileManager.default
    
    private var kernelQueue: Int32
    
    private var watchedDirectory: FileDescriptor = -1
    
    private var deinitNeeded = false
    
    private let handler: (FileEvent) -> Void
    
    @discardableResult
    public init(
        watch directoryPath: Path,
        with handler: @escaping (FileEvent) -> Void = { print($0) }
    ) throws {
        self.handler = handler
        kernelQueue = kqueue()
        guard kernelQueue >= 0 else { throw "⛔️ Failed to create kernel queue" }
        try watchDirectory(at: directoryPath)
        events.async(execute: fileEventsWatcher)
    }
    
    deinit {
        close(kernelQueue)
        closeWatched()
    }
    
    private func watchDirectory(at path: Path) throws {
        closeWatched()
        let directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
        try checkDirectoryPath(directoryURL)
        let descriptor = openForEventsAndGetDescriptor(at: directoryURL)
        guard descriptor > 0 else { throw "⛔️ Can't open file descriptor. Access denied" }
        print("\n📁 Started to watch events from \(directoryURL.lastPathComponent)/")
        watchedDirectory = descriptor
        createEventAtKernelQueue(from: watchedDirectory)
        try startReceivingChanges(at: directoryURL)
    }
    
    private func closeFile(_ desctiptor: FileDescriptor) {
        guard let url = watchedFiles[desctiptor] else { return }
        watchedFiles[desctiptor] = nil
        close(desctiptor)
        print("\n🏁 \(url.lastPathComponent) is no longer watched")
    }

    private func closeWatched() {
        watchedFiles.keys.forEach { closeFile($0) }
        close(watchedDirectory)
    }
    
    private func startReceivingChanges(at directory: URL) throws {
        try filesURLs(from: directory).forEach { addToWatch(at: $0) }
    }
    
    private func filesURLs(from directory: URL) throws -> [URL]  {
        return try fileManager
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    }
    
    private func openForEventsAndGetDescriptor(at pathURL: URL) -> FileDescriptor {
        return open(fileManager.fileSystemRepresentation(withPath: pathURL.path), O_EVTONLY)
    }
        
    private func addToWatch(at pathURL: URL) {
        let fileDescriptor = openForEventsAndGetDescriptor(at: pathURL)
        guard fileDescriptor > 0 else {
            print("⛔️ \(pathURL.lastPathComponent) can't be watched due to internal error")
            return
        }
        createEventAtKernelQueue(from: fileDescriptor)
        watchedFiles[fileDescriptor] = pathURL
        print("\n👁 \(pathURL.lastPathComponent) is now watched...")
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
        
    private func checkDirectoryPath(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if !fileExists {
            throw "⛔️ \(url.path) is invalid. Wrong path spelling or directory is not exist"
        }
        if !isDirectory.boolValue {
            throw "⛔️ Not a directory"
        }
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
            if deinitNeeded { break }
            guard amountOfEvents > 0 && event.filter == EVFILT_VNODE && event.fflags > 0
                else { continue }
            handleResult(of: event)
        }
    }
    
    private func calculateChecksum(_ checksum: inout String?, of fileURL: URL) {
        if let fileData = try? Data(contentsOf: fileURL) {
            checksum = fileData.SHA256hashString
        }
    }
    
    private func checkNewFiles(at directory: FileDescriptor) {
        let path = pathURL(for: directory)
        guard let newURLs = try? filesURLs(from: path) else { return }
        let oldURLs = watchedFiles.values
        guard newURLs.count != oldURLs.count else { return }
        var checksum: String?
        for url in newURLs {
            if oldURLs.contains(url) { continue }
            addToWatch(at: url)
            calculateChecksum(&checksum, of: url)
            handler(
                FileEvent(
                    fileName: url.lastPathComponent,
                    fileURL: url,
                    type: .newFile,
                    checksum: checksum
                )
            )
            break
        }
    }
    
    private func handleResult(of event: kevent) {
        let descriptor = FileDescriptor(event.ident)
        let flag = FilterFlag(rawValue: UInt32(event.fflags))
        
        if descriptor == watchedDirectory {
            if flag.contains(.delete) {
                deinitNeeded = true
                return
            }
            guard flag.contains(.write) else { return }
            checkNewFiles(at: descriptor)
            return
        }
        
        guard var fileURL = watchedFiles[descriptor] else { return }
        
        var checksum: String?
        var eventType: FileEvent.EventType = .error
            
        if flag.contains(.delete) {
            eventType = .delete
            closeFile(descriptor)
        }
        if flag.contains(.rename) {
            let newFileURL = pathURL(for: descriptor)
            if newFileURL.deletingLastPathComponent() == fileURL.deletingLastPathComponent() {
                eventType = .renamed(oldName: fileURL.lastPathComponent)
            } else {
                eventType = .moved(oldURL: fileURL)
            }
            watchedFiles[descriptor] = newFileURL
            fileURL = newFileURL
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
    }
}
