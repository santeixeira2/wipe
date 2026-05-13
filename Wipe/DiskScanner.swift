import Foundation
import Combine
import AppKit
import ServiceManagement
import UserNotifications

struct WipeTarget: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let safe: Bool
    let warning: String
    var sizeBytes: Int64 = 0
    var isLoading: Bool = true

    var sizeFormatted: String {
        isLoading ? "..." : ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var expandedPath: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? "/Users/\(NSUserName())"
        return path.replacingOccurrences(of: "~", with: home)
    }
}

@MainActor
class DiskScanner: ObservableObject {
    @Published var targets: [WipeTarget] = [
        WipeTarget(name: "DerivedData",      path: "~/Library/Developer/Xcode/DerivedData",         safe: true,  warning: "Xcode build cache. Completely safe to delete. Xcode rebuilds it automatically on the next build."),
        WipeTarget(name: "Xcode Archives",   path: "~/Library/Developer/Xcode/Archives",            safe: true,  warning: "Your archived app builds and debug symbols (dSYM). If you distribute via TestFlight or Firebase, these are used to re-sign builds and symbolicate crash logs. Safe to delete old ones, but you will lose crash symbolication for those versions."),
        WipeTarget(name: "iOS Simulators",   path: "~/Library/Developer/CoreSimulator/Devices",     safe: true,  warning: "All iOS simulator devices. Xcode will re-download them when needed, but it may take a while."),
        WipeTarget(name: "npm cache",        path: "~/.npm",                                        safe: true,  warning: "npm package cache. npm will re-download packages as needed."),
        WipeTarget(name: "Library/Caches",   path: "~/Library/Caches",                             safe: true,  warning: "System and app caches. Apps will recreate their caches automatically."),
        WipeTarget(name: "Android SDK",      path: "~/Library/Android",                            safe: true,  warning: "Android SDK, emulators and build tools. Delete if you no longer develop for Android on this Mac."),
        WipeTarget(name: "Arduino",          path: "~/Library/Arduino15",                          safe: true,  warning: "Arduino IDE libraries and packages. Delete if you no longer use Arduino on this Mac."),
        WipeTarget(name: "Cursor",           path: "~/Library/Application Support/Cursor",         safe: true,  warning: "Cursor app data including extensions and settings. This will reset Cursor to factory defaults."),
        WipeTarget(name: "Google Chrome",    path: "~/Library/Application Support/Google",         safe: true,  warning: "Chrome profile data including bookmarks, saved passwords, history and extensions. This cannot be undone."),
    ]

    @Published var freeSpace: String = ""
    @Published var totalSpace: String = ""
    @Published var freeSpaceGB: Double = 0

    @Published var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled) {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = !launchAtLogin
            }
        }
    }

    @Published var alertThresholdGB: Double = UserDefaults.standard.double(forKey: "alertThresholdGB") == 0
        ? 10
        : UserDefaults.standard.double(forKey: "alertThresholdGB") {
        didSet { UserDefaults.standard.set(alertThresholdGB, forKey: "alertThresholdGB") }
    }

    @Published var notificationsEnabled: Bool = false
    private var alreadyAlerted: Bool = false
    private var timer: Timer?

    init() {
        requestNotificationPermission()
        startMonitoring()
    }

    func refresh() {
        loadDiskSpace()
        for index in targets.indices {
            targets[index].isLoading = true
            targets[index].sizeBytes = 0
            let path = targets[index].expandedPath
            Task.detached(priority: .background) {
                let size = self.directorySize(at: path)
                await MainActor.run {
                    self.targets[index].sizeBytes = size
                    self.targets[index].isLoading = false
                }
            }
        }
    }

    func clean(target: WipeTarget) {
        guard target.safe else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \(target.name)?"
        alert.informativeText = "\(target.warning)\n\nThis will permanently delete \(target.sizeFormatted)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let url = URL(fileURLWithPath: target.expandedPath)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            let err = NSAlert()
            err.messageText = "Failed to delete \(target.name)"
            err.informativeText = error.localizedDescription
            err.runModal()
        }
        refresh()
    }

    func reveal(target: WipeTarget) {
        let url = URL(fileURLWithPath: target.expandedPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadDiskSpace()
                self?.checkThreshold()
            }
        }
    }

    private func checkThreshold() {
        guard notificationsEnabled else { return }
        if freeSpaceGB < alertThresholdGB && !alreadyAlerted {
            alreadyAlerted = true
            sendLowSpaceNotification()
        } else if freeSpaceGB >= alertThresholdGB {
            alreadyAlerted = false
        }
    }

    private func sendLowSpaceNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Low Disk Space"
        content.body = "Only \(freeSpace) remaining. Open Wipe to free up space."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "wipe.lowspace", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                self.notificationsEnabled = granted
            }
        }
    }

    private func loadDiskSpace() {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]),
           let free = values.volumeAvailableCapacity,
           let total = values.volumeTotalCapacity {
            freeSpaceGB = Double(free) / 1_073_741_824
            freeSpace = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
            totalSpace = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
        }
    }

    nonisolated private func directorySize(at path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
