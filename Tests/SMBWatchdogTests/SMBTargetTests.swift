import XCTest
@testable import SMBWatchdog

final class SMBTargetTests: XCTestCase {
    func testParsesDefaultShareAndMountPoint() throws {
        let target = try XCTUnwrap(SMBTarget(string: "smb://server/share"))

        XCTAssertEqual(target.url.absoluteString, "smb://server/share")
        XCTAssertEqual(target.mountPath, "/Volumes/share")
    }

    func testParsesEscapedShareName() throws {
        let target = try XCTUnwrap(SMBTarget(string: "smb://fileserver/Team%20Files"))

        XCTAssertEqual(target.mountPath, "/Volumes/Team Files")
    }

    func testRejectsCredentialsAndInvalidAddresses() {
        XCTAssertNil(SMBTarget(string: "smb://alice:secret@fileserver/share"))
        XCTAssertNil(SMBTarget(string: "https://fileserver/share"))
        XCTAssertNil(SMBTarget(string: "smb://fileserver"))
        XCTAssertNil(SMBTarget(string: "not a URL"))
    }
}
