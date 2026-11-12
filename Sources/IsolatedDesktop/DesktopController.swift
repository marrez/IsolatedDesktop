import AppKit
import UniformTypeIdentifiers
import Virtualization

@MainActor
final class DesktopController: NSObject, ObservableObject, VZVirtualMachineDelegate {
    @Published var options = IsolationOptions()
    @Published private(set) var machine: VZVirtualMachine?
    @Published private(set) var busy = false
    @Published private(set) var status = "Prêt"
    @Published private(set) var installed = false
    @Published private(set) var installing = false
    @Published var errorMessage: String?

    private let store = MachineStore()
    private var installer: VZMacOSInstaller?
    private var temporaryDirectory: URL?

    override init() {
        super.init()
        installed = store.isInstalled
    }

    func chooseSharedDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { options.sharedDirectory = panel.url }
    }

    func install() {
        guard !busy, machine == nil, !installed, VZVirtualMachine.isSupported else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ipsw") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let imageURL = panel.url else { return }
        busy = true
        installing = true
        status = "Lecture de l’image IPSW…"
        VZMacOSRestoreImage.load(from: imageURL) { result in
            Task { @MainActor in
                do {
                    let image = try result.get()
                    try self.prepareInstallation(image: image, imageURL: imageURL)
                } catch { self.fail(error) }
            }
        }
    }

    private func prepareInstallation(image: VZMacOSRestoreImage, imageURL: URL) throws {
        guard let requirements = image.mostFeaturefulSupportedConfiguration else {
            throw MachineConfiguration.ConfigurationError.unsupportedMachine
        }
        let directory = try store.createInstallationDirectory()
        let cpuCount = max(requirements.minimumSupportedCPUCount,
                           min(4, VZVirtualMachineConfiguration.maximumAllowedCPUCount))
        let memory = max(requirements.minimumSupportedMemorySize, UInt64(4 * 1024 * 1024 * 1024))
        let metadata = MachineMetadata(cpuCount: cpuCount, memorySize: memory)
        try requirements.hardwareModel.dataRepresentation.write(to: directory.appendingPathComponent(MachineFiles.hardware))
        try VZMacMachineIdentifier().dataRepresentation.write(to: directory.appendingPathComponent(MachineFiles.identifier))
        _ = try VZMacAuxiliaryStorage(creatingStorageAt: directory.appendingPathComponent(MachineFiles.auxiliary),
                                     hardwareModel: requirements.hardwareModel, options: [])
        let disk = directory.appendingPathComponent(MachineFiles.disk)
        guard FileManager.default.createFile(atPath: disk.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: disk)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 64 * 1024 * 1024 * 1024)
        try JSONEncoder().encode(metadata).write(to: directory.appendingPathComponent(MachineFiles.metadata))
        let vm = VZVirtualMachine(configuration: try MachineConfiguration.make(directory: directory,
            options: IsolationOptions(networkEnabled: options.networkEnabled, temporarySession: false)))
        vm.delegate = self
        machine = vm
        let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: imageURL)
        self.installer = installer
        status = "Installation de macOS — ne quitte pas l’application…"
        installer.install { result in
            Task { @MainActor in
                self.installer = nil
                do {
                    try result.get()
                    // The installer has completed; release its VM before moving the bundle.
                    self.machine = nil
                    try self.store.commitInstallation(directory)
                    self.installed = true
                    self.busy = false
                    self.installing = false
                    self.status = "macOS installé. Lance une session conservée pour terminer l’assistant de configuration."
                    self.options.temporarySession = false
                } catch { self.fail(error) }
            }
        }
    }

    func start() {
        guard installed, !busy, machine == nil else { return }
        busy = true
        status = "Préparation du bureau…"
        let temporary = options.temporarySession
        let store = self.store
        Task {
            do {
                // Disk copying must not block the UI.
                let directory = try await Task.detached {
                    try temporary ? store.createSession() : store.base
                }.value
                if temporary { temporaryDirectory = directory }
                let vm = VZVirtualMachine(configuration: try MachineConfiguration.make(directory: directory, options: options))
                vm.delegate = self
                machine = vm
                vm.start { result in
                    Task { @MainActor in
                        switch result {
                        case .success:
                            self.busy = false
                            self.status = temporary ? "Bureau temporaire actif" : "Bureau conservé actif"
                        case .failure(let error): self.fail(error)
                        }
                    }
                }
            } catch { fail(error) }
        }
    }

    func requestShutdown() {
        guard let machine, !busy, machine.canRequestStop else { return }
        do {
            try machine.requestStop()
            status = "Arrêt demandé — termine la session dans le macOS invité."
        } catch { errorMessage = error.localizedDescription }
    }

    func forceStop() {
        guard let machine, !busy, machine.canStop else { return }
        busy = true
        machine.stop { error in
            Task { @MainActor in
                guard self.machine === machine else { return }
                if let error {
                    self.busy = false
                    self.errorMessage = error.localizedDescription
                } else {
                    self.finishSession()
                }
            }
        }
    }

    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        Task { @MainActor in
            guard !self.installing, self.machine === virtualMachine else { return }
            self.finishSession()
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        Task { @MainActor in
            guard !self.installing, self.machine === virtualMachine else { return }
            self.fail(error)
        }
    }

    private func finishSession() {
        machine = nil
        busy = false
        if let directory = temporaryDirectory {
            temporaryDirectory = nil
            do { try store.removeSession(directory) }
            catch { errorMessage = "Session arrêtée, mais suppression impossible : \(error.localizedDescription)" }
        }
        status = "Bureau arrêté"
    }

    private func fail(_ error: Error) {
        installer = nil
        installing = false
        // Preserve failed installation files for diagnosis. Only session copies are removed.
        finishSession()
        errorMessage = error.localizedDescription
        status = "Échec — consulte le message d’erreur"
    }
}
