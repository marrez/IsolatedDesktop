import Foundation

struct MachineStore {
    let root: URL

    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("IsolatedDesktop", isDirectory: true)) {
        self.root = root
    }

    var base: URL { root.appendingPathComponent("Base", isDirectory: true) }
    var sessions: URL { root.appendingPathComponent("Sessions", isDirectory: true) }
    var isInstalled: Bool { FileManager.default.fileExists(atPath: base.appendingPathComponent(MachineFiles.metadata).path) }

    func createInstallationDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = root.appendingPathComponent("Installation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    func commitInstallation(_ directory: URL) throws {
        // Never overwrite an existing base or a directory not created by this app.
        guard directory.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL,
              directory.lastPathComponent.hasPrefix("Installation-"),
              !FileManager.default.fileExists(atPath: base.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.moveItem(at: directory, to: base)
    }

    func createSession() throws -> URL {
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let destination = sessions.appendingPathComponent(UUID().uuidString, isDirectory: true)
        // On APFS, the filesystem may optimize copying via copy-on-write.
        // Never hard-link writable disks or auxiliary storage to the base.
        try FileManager.default.copyItem(at: base, to: destination)
        return destination
    }

    func removeSession(_ directory: URL) throws {
        guard directory.deletingLastPathComponent().standardizedFileURL == sessions.standardizedFileURL,
              UUID(uuidString: directory.lastPathComponent) != nil else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try FileManager.default.removeItem(at: directory)
    }
}
