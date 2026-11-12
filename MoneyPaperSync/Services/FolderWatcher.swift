import Foundation
import CoreServices

/// Überwacht einen Ordner (rekursiv) per FSEvents und meldet Änderungen gebündelt.
@MainActor
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private var onChange: (() -> Void)?

    var isRunning: Bool { stream != nil }

    func start(path: String, onChange: @escaping () -> Void) {
        stop()
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.fire() }
        }

        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            3.0, // Latenz in Sekunden: bündelt Schreibvorgänge, bis die PDF vollständig ist
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        onChange = nil
    }

    private func fire() {
        onChange?()
    }
}
