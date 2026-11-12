import AppKit
import SwiftUI
import Virtualization

@main
struct IsolatedDesktopApp: App {
    @StateObject private var controller = DesktopController()
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate

    var body: some Scene {
        Window("Isolated Desktop", id: "desktop") {
            DesktopView(controller: controller)
                .onAppear { delegate.controller = controller }
        }
        .defaultSize(width: 1150, height: 780)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var controller: DesktopController?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller, controller.machine != nil || controller.busy else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Stop the isolated desktop first"
        alert.informativeText = "Stop the virtual machine before quitting to avoid interrupting installation or disk writes."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct DesktopView: View {
    @ObservedObject var controller: DesktopController
    @State private var confirmForceStop = false

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Isolated Desktop", systemImage: "desktopcomputer")
                    .font(.title2.bold())
                Text("A separate macOS, on your Mac.").foregroundStyle(.secondary)
                Divider()
                Toggle("Allow network", isOn: $controller.options.networkEnabled)
                Text(controller.options.networkEnabled
                     ? "NAT networking: no VPN or anonymity. Your local network may remain accessible."
                     : "No network adapter is attached to the VM.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Temporary session", isOn: $controller.options.temporarySession)
                Text("The session copy is deleted after shutdown. The reference system is kept. This is not secure erasure.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Host files").font(.headline)
                if let directory = controller.options.sharedDirectory {
                    Text(directory.path).font(.caption).textSelection(.enabled)
                    Text("Read-only").foregroundStyle(.secondary)
                    Button("Remove sharing") { controller.options.sharedDirectory = nil }
                } else {
                    Text("No shared folder").foregroundStyle(.secondary)
                }
                Button("Choose a folder…") { controller.chooseSharedDirectory() }
                Text("Clipboard, camera, and microphone are not shared.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !controller.installed {
                    Button("Install macOS from an IPSW…") { controller.install() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Open isolated desktop") { controller.start() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24).frame(minWidth: 290, idealWidth: 310, maxWidth: 370)
            .disabled(controller.busy || controller.machine != nil)

            VStack(spacing: 0) {
                HStack {
                    if controller.busy { ProgressView().controlSize(.small) }
                    Text(controller.status).font(.callout)
                    Spacer()
                    if controller.machine != nil && !controller.installing {
                        Button("Shut down") { controller.requestShutdown() }
                        Button("Force stop", role: .destructive) { confirmForceStop = true }
                    }
                }.padding().disabled(controller.busy)
                Divider()
                if let machine = controller.machine {
                    VirtualDesktop(machine: machine)
                } else {
                    ContentUnavailableView {
                        Label("Isolated macOS desktop", systemImage: "lock.desktopcomputer")
                    } description: {
                        Text(controller.installed
                            ? "For first-time setup, use a persistent session to finish configuring macOS."
                            : "Choose a restore IPSW compatible with your Mac. Allow enough disk space for macOS and session copies.")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 550, minHeight: 550)
        }
        .alert("Error", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )) { Button("OK") { controller.errorMessage = nil } }
        message: { Text(controller.errorMessage ?? "") }
        .alert("Force stop the desktop?", isPresented: $confirmForceStop) {
            Button("Cancel", role: .cancel) {}
            Button("Force stop", role: .destructive) { controller.forceStop() }
        } message: {
            Text("Unsaved work will be lost. Files in a persistent session may become corrupted.")
        }
    }
}

struct VirtualDesktop: NSViewRepresentable {
    let machine: VZVirtualMachine

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.virtualMachine = machine
        view.capturesSystemKeys = true
        view.automaticallyReconfiguresDisplay = true
        return view
    }

    func updateNSView(_ view: VZVirtualMachineView, context: Context) {
        view.virtualMachine = machine
    }
}
