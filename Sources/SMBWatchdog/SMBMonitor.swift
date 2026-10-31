import AppKit
import Darwin
import Foundation

@MainActor
final class SMBMonitor: ObservableObject {
    static let shared = SMBMonitor()

    enum Status: Equatable {
        case checking
        case connected
        case connecting
        case disconnected
        case error(String)

        var title: String {
            switch self {
            case .checking: "Checking"
            case .connected: "Connected"
            case .connecting: "Reconnecting"
            case .disconnected: "Disconnected"
            case .error: "Error"
            }
        }

        var symbol: String {
            switch self {
            case .connected: "checkmark.circle.fill"
            case .connecting, .checking: "arrow.triangle.2.circlepath"
            case .disconnected, .error: "exclamationmark.triangle.fill"
            }
        }
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var lastChecked: Date?
    @Published private(set) var lastAttempt: Date?

    private let queue = DispatchQueue(label: "com.helenfac.SMBWatchdog.monitor")
    private var isChecking = false
    private var timer: Timer?
    private let retryInterval: TimeInterval = 60

    func startMonitoring() {
        guard timer == nil else { return }
        checkNow()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkNow()
            }
        }
    }

    func checkNow(forceReconnect: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

        let shareAddress = UserDefaults.standard.string(forKey: "shareURL") ?? Self.defaultShareAddress
        guard let target = SMBTarget(string: shareAddress) else {
            status = .error("Enter a valid smb://server/share address without a username or password.")
            lastChecked = Date()
            isChecking = false
            return
        }

        status = .checking
        queue.async { [weak self] in
            let result = Self.check(target)
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastChecked = Date()
                self.isChecking = false

                switch result {
                case .connected:
                    self.status = .connected
                case .unavailable:
                    self.reconnect(to: target, force: forceReconnect)
                case .failure(let message):
                    self.status = .error(message)
                }
            }
        }
    }

    static let defaultShareAddress = "smb://server/share"

    private enum CheckResult {
        case connected
        case unavailable
        case failure(String)
    }

    private func reconnect(to target: SMBTarget, force: Bool) {
        let now = Date()
        if !force, let lastAttempt, now.timeIntervalSince(lastAttempt) < retryInterval {
            status = .disconnected
            return
        }

        lastAttempt = now
        status = .connecting
        guard NSWorkspace.shared.open(target.url) else {
            status = .error("macOS could not open the SMB share.")
            return
        }
    }

    private nonisolated static func check(_ target: SMBTarget) -> CheckResult {
        var filesystem = statfs()
        guard target.mountPath.withCString({ statfs($0, &filesystem) }) == 0 else {
            return .unavailable
        }

        let mountedPath = withUnsafeBytes(of: filesystem.f_mntonname) {
            String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        let filesystemType = withUnsafeBytes(of: filesystem.f_fstypename) {
            String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        guard mountedPath == target.mountPath, filesystemType == "smbfs" else {
            return .unavailable
        }

        switch run("/bin/ls", arguments: ["-A", target.mountPath], captureOutput: false) {
        case .failure(let error):
            return .failure(error)
        case .success(let result):
            guard result.status == 0 else { return .unavailable }
        }

        switch run("/usr/bin/smbutil", arguments: ["statshares", "-m", target.mountPath, "-f", "Json"]) {
        case .failure(let error):
            return .failure(error)
        case .success(let result):
            return result.status == 0 ? .connected : .unavailable
        }
    }

    private struct CommandResult {
        let status: Int32
        let output: String
    }

    private enum CommandOutcome {
        case success(CommandResult)
        case failure(String)
    }

    private nonisolated static func run(
        _ executable: String,
        arguments: [String],
        captureOutput: Bool = true
    ) -> CommandOutcome {
        let process = Process()
        let output = captureOutput ? Pipe() : nil
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output ?? FileHandle.nullDevice
        process.standardError = output ?? FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }

        do {
            try process.run()
        } catch {
            return .failure("Could not run \(URL(fileURLWithPath: executable).lastPathComponent): \(error.localizedDescription)")
        }

        if finished.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut {
                _ = Darwin.kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 1)
            }
            return .failure("\(URL(fileURLWithPath: executable).lastPathComponent) timed out while checking the share.")
        }

        let data = output?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        return .success(CommandResult(status: process.terminationStatus, output: text))
    }
}
