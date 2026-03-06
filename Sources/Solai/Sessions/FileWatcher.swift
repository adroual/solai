import Foundation
import CoreServices

final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let path: String
    private let onChange: () -> Void

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            let hasSolaiEvent = paths.contains { $0.contains("solai_state_") || $0.contains("solai_meta_") }

            if hasSolaiEvent || numEvents > 0 {
                DispatchQueue.main.async {
                    watcher.onChange()
                }
            }
        }

        let pathsToWatch = [path] as CFArray
        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // 300ms latency — batches rapid writes
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, .main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    deinit {
        stop()
    }
}
