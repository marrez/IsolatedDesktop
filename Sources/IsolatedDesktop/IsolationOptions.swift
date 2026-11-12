import Foundation

struct IsolationOptions {
    var networkEnabled = false
    var temporarySession = true
    var sharedDirectory: URL?
}

struct MachineMetadata: Codable {
    let cpuCount: Int
    let memorySize: UInt64
}

enum MachineFiles {
    static let disk = "Disk.img"
    static let hardware = "HardwareModel.bin"
    static let identifier = "MachineIdentifier.bin"
    static let auxiliary = "AuxiliaryStorage.bin"
    static let metadata = "Machine.json"
}
