import Foundation

struct SMBTarget: Equatable, Sendable {
    let url: URL
    let mountPath: String

    init?(string: String) {
        guard
            let components = URLComponents(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
            components.scheme?.lowercased() == "smb",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil
        else {
            return nil
        }

        let pathComponents = components.path.split(separator: "/", omittingEmptySubsequences: true)

        guard
            pathComponents.count == 1,
            let shareName = pathComponents.first.map(String.init),
            shareName != ".",
            shareName != "..",
            !shareName.contains("/"),
            let url = components.url
        else {
            return nil
        }

        self.url = url
        self.mountPath = "/Volumes/\(shareName)"
    }
}
