import AppKit
import ServiceManagement
import SwiftUI

@main
struct SMBWatchdogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = SMBMonitor.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            Label("SMB Watchdog", systemImage: monitor.status.symbol)
        }
        .menuBarExtraStyle(.window)

        Window("SMB Watchdog Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        SMBMonitor.shared.startMonitoring()
    }
}

private struct MenuContent: View {
    @ObservedObject var monitor: SMBMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(monitor.status.title, systemImage: monitor.status.symbol)
                .font(.headline)

            Text(UserDefaults.standard.string(forKey: "shareURL") ?? SMBMonitor.defaultShareAddress)
                .font(.caption)
                .textSelection(.enabled)

            if let lastChecked = monitor.lastChecked {
                Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if case .error(let message) = monitor.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Check Now") {
                monitor.checkNow()
            }
            .disabled(monitor.status == .checking)

            Button("Reconnect Now") {
                monitor.checkNow(forceReconnect: true)
            }
            .disabled(monitor.status == .checking || monitor.status == .connecting)

            Button("Settings…") {
                openWindow(id: "settings")
            }

            Divider()

            Button("Quit SMB Watchdog") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 290)
    }
}

private struct SettingsView: View {
    @AppStorage("shareURL") private var shareURL = SMBMonitor.defaultShareAddress
    @State private var loginItemMessage: String?

    private var loginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var body: some View {
        Form {
            TextField("SMB share address", text: $shareURL)
                .textFieldStyle(.roundedBorder)

            Text("Example: smb://server/share. macOS Finder handles sign-in; passwords are not stored by this app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent("Expected mount point") {
                Text(SMBTarget(string: shareURL)?.mountPath ?? "Enter a valid share address")
                    .textSelection(.enabled)
            }

            Button(loginItemEnabled ? "Disable Open at Login" : "Enable Open at Login") {
                setLoginItemEnabled(!loginItemEnabled)
            }

            if let loginItemMessage {
                Text(loginItemMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func setLoginItemEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemMessage = enabled ? "SMB Watchdog will open at login." : "Open at login is disabled."
        } catch {
            loginItemMessage = "Could not update the login item: \(error.localizedDescription)"
        }
    }
}
