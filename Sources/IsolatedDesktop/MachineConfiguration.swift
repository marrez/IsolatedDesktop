import Foundation
import Virtualization

enum MachineConfiguration {
    static func make(directory: URL, options: IsolationOptions) throws -> VZVirtualMachineConfiguration {
        let metadata = try JSONDecoder().decode(MachineMetadata.self,
            from: Data(contentsOf: directory.appendingPathComponent(MachineFiles.metadata)))
        guard let hardware = VZMacHardwareModel(dataRepresentation:
            try Data(contentsOf: directory.appendingPathComponent(MachineFiles.hardware))),
              hardware.isSupported,
              let identifier = VZMacMachineIdentifier(dataRepresentation:
            try Data(contentsOf: directory.appendingPathComponent(MachineFiles.identifier))) else {
            throw ConfigurationError.unsupportedMachine
        }

        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardware
        platform.machineIdentifier = identifier
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url:
            directory.appendingPathComponent(MachineFiles.auxiliary))

        let configuration = VZVirtualMachineConfiguration()
        configuration.platform = platform
        configuration.bootLoader = VZMacOSBootLoader()
        configuration.cpuCount = metadata.cpuCount
        configuration.memorySize = metadata.memorySize
        configuration.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment:
            try VZDiskImageStorageDeviceAttachment(url: directory.appendingPathComponent(MachineFiles.disk),
                                                  readOnly: false))]

        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [VZMacGraphicsDisplayConfiguration(widthInPixels: 1920, heightInPixels: 1200,
                                                               pixelsPerInch: 144)]
        configuration.graphicsDevices = [graphics]
        configuration.keyboards = [VZUSBKeyboardConfiguration()]
        configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

        if options.networkEnabled {
            let network = VZVirtioNetworkDeviceConfiguration()
            network.attachment = VZNATNetworkDeviceAttachment()
            configuration.networkDevices = [network]
        }
        if let directory = options.sharedDirectory {
            let share = VZVirtioFileSystemDeviceConfiguration(tag: "com.apple.virtio-fs.automount")
            share.share = VZSingleDirectoryShare(directory: VZSharedDirectory(url: directory, readOnly: true))
            configuration.directorySharingDevices = [share]
        }
        // No clipboard agent, host sockets, USB passthrough, camera or microphone.
        try configuration.validate()
        return configuration
    }

    enum ConfigurationError: LocalizedError {
        case unsupportedMachine
        var errorDescription: String? { "Ce modèle de machine virtuelle n’est pas compatible avec ce Mac." }
    }
}
