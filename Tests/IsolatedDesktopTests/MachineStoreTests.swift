import XCTest
@testable import IsolatedDesktop

final class MachineStoreTests: XCTestCase {
    func testDefaultsAreRestrictive() {
        let options = IsolationOptions()
        XCTAssertFalse(options.networkEnabled)
        XCTAssertTrue(options.temporarySession)
        XCTAssertNil(options.sharedDirectory)
    }

    func testSessionDoesNotModifyBase() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MachineStore(root: root)
        let installation = try store.createInstallationDirectory()
        try Data("original".utf8).write(to: installation.appendingPathComponent(MachineFiles.disk))
        try store.commitInstallation(installation)
        let session = try store.createSession()
        try Data("modified".utf8).write(to: session.appendingPathComponent(MachineFiles.disk))
        XCTAssertEqual(try String(contentsOf: store.base.appendingPathComponent(MachineFiles.disk)), "original")
        try store.removeSession(session)
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.base.path))
    }

    func testCannotRemoveBaseAsSession() throws {
        let store = MachineStore(root: URL(fileURLWithPath: "/nonexistent/IsolatedDesktop-tests"))
        XCTAssertThrowsError(try store.removeSession(store.base))
        XCTAssertThrowsError(try store.removeSession(store.sessions.appendingPathComponent("arbitrary")))
    }
}
