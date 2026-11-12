#if DEBUG
import AppKit
import SwiftUI

/// Nur Debug: Mit `-snapshotDir <Name>` schreibt die App PNGs aller Bereiche und beendet sich.
@MainActor
enum DebugSnapshots {
    static func runIfRequested(env: AppEnvironment) {
        guard let dir = UserDefaults.standard.string(forKey: "snapshotDir") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(dir, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            if env.settings.onboardingCompleted {
                for item in SidebarItem.allCases {
                    env.navigate(to: item)
                    try? await Task.sleep(for: .seconds(1))
                    write("\(item.title)", to: url)
                }
            } else {
                write("Onboarding", to: url)
            }
            NSApp.terminate(nil)
        }
    }

    private static func write(_ name: String, to dir: URL) {
        guard let view = NSApp.windows.first?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
#endif
