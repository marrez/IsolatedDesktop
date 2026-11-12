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
        alert.messageText = "Arrête d’abord le bureau isolé"
        alert.informativeText = "Pour éviter une interruption de l’installation ou des écritures disque, arrête la VM avant de quitter."
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
                Text("Un macOS distinct, sur ton Mac.").foregroundStyle(.secondary)
                Divider()
                Toggle("Autoriser le réseau", isOn: $controller.options.networkEnabled)
                Text(controller.options.networkEnabled
                     ? "Réseau NAT : ni VPN ni anonymisation. Le réseau local peut rester accessible."
                     : "Aucune carte réseau exposée à la VM.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Session temporaire", isOn: $controller.options.temporarySession)
                Text("La copie de session est supprimée après l’arrêt. La base reste conservée. Ce n’est pas un effacement sécurisé.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Fichiers du Mac").font(.headline)
                if let directory = controller.options.sharedDirectory {
                    Text(directory.path).font(.caption).textSelection(.enabled)
                    Text("Lecture seule").foregroundStyle(.secondary)
                    Button("Retirer le partage") { controller.options.sharedDirectory = nil }
                } else {
                    Text("Aucun dossier partagé").foregroundStyle(.secondary)
                }
                Button("Choisir un dossier…") { controller.chooseSharedDirectory() }
                Text("Presse-papiers, caméra et microphone non partagés.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !controller.installed {
                    Button("Installer macOS depuis un IPSW…") { controller.install() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Ouvrir le bureau isolé") { controller.start() }
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
                        Button("Arrêter") { controller.requestShutdown() }
                        Button("Forcer l’arrêt", role: .destructive) { confirmForceStop = true }
                    }
                }.padding().disabled(controller.busy)
                Divider()
                if let machine = controller.machine {
                    VirtualDesktop(machine: machine)
                } else {
                    ContentUnavailableView {
                        Label("Bureau isolé macOS", systemImage: "lock.desktopcomputer")
                    } description: {
                        Text(controller.installed
                            ? "Pour la première utilisation, conserve la session afin de terminer la configuration de macOS."
                            : "Choisis une image de restauration IPSW compatible avec ton M4. Prévois de l’espace disque pour macOS et ses sessions.")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(minWidth: 550, minHeight: 550)
        }
        .alert("Erreur", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )) { Button("OK") { controller.errorMessage = nil } }
        message: { Text(controller.errorMessage ?? "") }
        .alert("Forcer l’arrêt du bureau ?", isPresented: $confirmForceStop) {
            Button("Annuler", role: .cancel) {}
            Button("Forcer l’arrêt", role: .destructive) { controller.forceStop() }
        } message: {
            Text("Les données non enregistrées seront perdues. Une session conservée peut subir une corruption de fichiers.")
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
