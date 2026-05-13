import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = DiskScanner()

    var body: some View {
        Group {
            diskHeader
            Divider()
            ForEach(scanner.targets) { target in
                TargetRow(target: target, scanner: scanner)
            }
            Divider()
            settingsSection
            Divider()
            Button("Refresh") { scanner.refresh() }
                .keyboardShortcut("r")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .onAppear { scanner.refresh() }
    }

    private var diskHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Disk Space")
                .font(.headline)
            if !scanner.freeSpace.isEmpty {
                Text("\(scanner.freeSpace) free of \(scanner.totalSpace)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var settingsSection: some View {
        Group {
            Toggle("Launch at Login", isOn: $scanner.launchAtLogin)
            if scanner.notificationsEnabled {
                Menu("Alert below \(Int(scanner.alertThresholdGB)) GB") {
                    ForEach([5, 10, 15, 20, 30], id: \.self) { gb in
                        Button {
                            scanner.alertThresholdGB = Double(gb)
                        } label: {
                            HStack {
                                Text("\(gb) GB")
                                if Int(scanner.alertThresholdGB) == gb {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } else {
                Button("Enable Notifications...") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                }
            }
        }
    }
}

struct TargetRow: View {
    let target: WipeTarget
    let scanner: DiskScanner

    var body: some View {
        Button {
            scanner.clean(target: target)
        } label: {
            HStack {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .frame(width: 16)
                Text(target.name)
                Spacer()
                Text(target.sizeFormatted)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}
