# Isolated Desktop

Run a **separate macOS desktop inside a virtual machine on your Apple Silicon Mac**, including M4.

Built with **SwiftUI** and Apple’s **Virtualization framework**. No third-party hypervisor is required.

> **Experimental, unaudited prototype.** Compilation and unit tests have been verified locally. Full guest macOS installation and startup still need end-to-end validation. This application does not provide a VPN, guaranteed anonymity, or protection against a compromised host Mac.

## Features

- Install guest macOS from a restore IPSW image you provide.
- Use the virtual desktop in a window or full screen.
- Networking disabled by default, with optional NAT networking.
- No host folders shared by default; optionally share one folder as read-only.
- No clipboard sharing, camera, microphone, or USB passthrough configured.
- Choose persistent sessions or temporary sessions based on a copy of the reference system.
- Request a normal shutdown or force a stop with confirmation.

## Requirements

- **Apple Silicon Mac**: M1 or newer. The initial target is M4; Intel Macs are not supported by this macOS guest prototype.
- **macOS 14 or later** on the host.
- **Xcode 15 or later**, including its development tools, to build the application. Compatibility with every Xcode version has not been tested.
- An **official Apple macOS restore IPSW image** compatible with your hardware and host macOS version.
- Enough memory for both systems. The application assigns at least **4 GiB of RAM** to the guest, or more if the restore image requires it.
- Enough free storage for the IPSW, the installed system, and session copies. The guest disk has a logical capacity of **64 GiB**.

macOS images are not included. Downloading and using them is subject to Apple’s license terms.

## Build and launch

This prototype currently requires a local build. Open Terminal in the project folder and run:

```sh
zsh scripts/build-app.sh
open "dist/Isolated Desktop.app"
```

The script creates `dist/Isolated Desktop.app` and signs it locally with the required virtualization entitlement. An Apple Developer account is not required for this local build.

Do not launch it using `swift run`: the executable needs the entitlement added by the build script. Local signing is not the same as Developer ID signing or Apple notarization.

## First-time setup

The application’s own labels and messages are in English. Native macOS dialogs and system-provided error details may follow your system language. The guest macOS language is selected separately during guest setup.

1. Obtain an **official Apple macOS restore IPSW** compatible with your Mac. An installer `.app` or an ISO file will not work. The application does not download the image automatically.
2. Click **“Install macOS from an IPSW…”** and select your image.
3. Wait for installation to finish. Do not quit the application during installation. The guest disk is allocated progressively; installation and session copies still require sufficient free storage.
4. Open a **persistent session** with **“Temporary session”** turned **off**. Complete macOS Setup Assistant and create a separate local account. Enable networking only if needed; some setup steps and updates may require it.
5. Shut down the guest properly. The reference system now contains your configured desktop.
6. For a disposable workspace, turn **“Temporary session”** on and click **“Open isolated desktop”**.

Use the green window button to enter full screen. This places the application in its own macOS Space, but the **virtual machine**, not the Space, provides isolation.

## Everyday use

### Persistent or temporary sessions

| Mode | What happens to your changes? |
| --- | --- |
| **Persistent** — Temporary session off | Changes are saved directly to the reference system and remain available next time. Use this mode for initial setup, app installation, and system updates. |
| **Temporary** — Temporary session on | The application copies the reference system before starting. Changes affect only that copy, which is deleted after the VM stops. |

Files you want to keep should not exist only inside a temporary session. Update the reference system regularly using persistent mode.

Temporary sessions are **not secure erasure**. Backups and filesystem snapshots may retain data. Sessions interrupted by a crash may remain on disk.

### Network access

**“Allow network”** is off by default. In this state, no virtual network adapter is attached.

When enabled, the application uses standard NAT networking:

- Your public IP address is **not hidden**.
- Devices and services on your local network may be accessible from the guest.
- No VPN, kill switch, or destination filtering is provided.

Stop the VM before changing its network settings.

### Sharing files with the guest

Click **“Choose a folder…”** to expose a host folder as **read-only**. Click **“Remove sharing”** to remove it before the next start.

The selected folder is shared through VirtioFS, with automatic mounting in a compatible guest macOS version. Treat all contents of that folder as readable by guest applications.

Read-only sharing prevents modification through that share. It does **not** prevent the guest from copying the contents or uploading them if networking is enabled. Avoid sharing sensitive folders.

### Shutting down

- Prefer shutting down from inside guest macOS, or click **“Shut down”** to request a shutdown.
- Use **“Force stop”** only when necessary. Unsaved work may be lost, and a persistent disk may suffer filesystem corruption.
- Stop the VM before quitting the application.

## How isolation works

Guest macOS runs with its own kernel, memory, and virtual disk. Apple’s Virtualization framework and hardware virtualization provide the boundary between the guest and your host macOS system.

```text
Apple Silicon Mac — host macOS
└── Isolated Desktop
    └── Apple Virtualization framework
        └── Guest macOS
            ├── Dedicated virtual disk
            ├── No networking by default
            └── Optional read-only host folder
```

The guest is not automatically given access to your host documents or keychain. Shared folders and enabled network access create additional paths for data exchange.

### Security and privacy limitations

- **Isolation is not anonymity.** Personal accounts, uploaded documents, browser fingerprints, and metadata can still link activity to you.
- Do not sign in to iCloud or personal accounts if your goal is to keep identities separate.
- A compromised host may observe or interfere with the guest.
- The host application itself does **not yet use App Sandbox**. Its virtualization entitlement does not restrict all of its host file access.
- Vulnerabilities in virtualization software could compromise isolation. This prototype is not a validated malware-analysis environment.
- No clipboard-sharing agent, camera, microphone, or USB passthrough is configured; this is not a guarantee against every possible data leak.
- Do not run two independent application instances against the same reference system. Cross-process locking is not implemented yet.

## Where your data is stored

Application data is stored locally in:

```text
~/Library/Application Support/IsolatedDesktop/
```

- `Base/`: the installed reference system, including changes made in persistent sessions.
- `Sessions/`: temporary session copies.
- `Installation-…/`: installation working directories; failed installations may remain for diagnosis.

Temporary session copies are deleted after a normal stop or successful forced stop. There is no automatic startup cleanup for sessions left behind by a crash.

Do not move or delete VM files while the application is installing or running a guest. Deleting the reference system removes the installed guest and its saved data, so back up anything important first.

## Cleaning

**Always stop the guest and quit Isolated Desktop before cleaning VM data.** Ensure no other instance is running. Back up any files you want to keep first. There is no in-app cleanup manager yet.

### Remove leftover temporary sessions

Temporary session copies are normally deleted when the VM stops. After a crash, some copies may remain:

1. In Finder, choose **Go → Go to Folder…** (`Shift–Command–G`).
2. Enter `~/Library/Application Support/IsolatedDesktop/Sessions/`.
3. Move only the abandoned session folders you no longer need to the Trash. Their names are UUIDs, such as `12345678-1234-1234-1234-123456789ABC`.

This leaves `Base/` intact. However, deleting a session permanently discards any work stored only in that copy once the Trash is emptied. Recover any needed data before deleting it.

### Remove failed installation files

Open `~/Library/Application Support/IsolatedDesktop/` in Finder. Folders named `Installation-…` may remain after a failed installation. Once the application is closed and you no longer need them for troubleshooting, move those folders to the Trash. Do not remove `Base/` as part of routine cleanup.

### Reset the installed guest

**This deletes the reference system, installed guest apps, and all persistent-session data.** With the application closed, back up anything important, then move `Base/` to the Trash. Move any unwanted copies from `Sessions/` as well; those copies may still contain previous guest data.

Next time you open the application, install macOS again from an IPSW.

### Remove build files or uninstall

- If you built from source, you can delete `.build/` inside the project to reclaim build-cache space. Stop any build or test process first. It will be recreated on the next build.
- You can delete `dist/` to remove the generated application. Re-run the build script to recreate it. Neither folder contains the installed guest by default.
- To remove all local VM data, first stop the guest and quit the application, then move `~/Library/Application Support/IsolatedDesktop/` to the Trash. **This removes the reference system, session copies, and installation files.**
- Delete any downloaded IPSW separately if you no longer need it. Keep it if you want to reinstall without downloading it again.

Moving files to the Trash does not immediately reclaim their storage; empty it only after checking that you no longer need them. Cleanup is **not secure erasure**: Time Machine backups, APFS snapshots, and other copies may retain data.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Swift or SDK tools cannot be found | Install Xcode, finish its first-launch setup, and select its command-line tools under Xcode → Settings → Locations. |
| The VM will not start | Use the application generated by the build script, not an unsigned executable. Check IPSW compatibility and available resources. |
| The guest has no Internet access | Networking is off by default. Stop the VM, enable networking, and start it again. |
| Setup Assistant appears again | Complete setup in a **persistent** session and shut the guest down properly before switching to temporary mode. |
| Installation or session preparation needs more space | Make room for the guest disk and session copies. The 64 GiB disk capacity does not include the IPSW or additional copies. |
| Session files remain after a crash | They are retained in the application data directory. Stop the application and ensure no VM is running before managing these files. |

## Current status

Local compilation, application signing, and three unit tests have passed. Those tests cover restrictive defaults, session-copy independence, and safeguards around session deletion. They are **not** an end-to-end installation test or a security audit.

Planned improvements include:

- End-to-end installation and startup validation on M4.
- An integrated Apple restore-image download flow with progress and cancellation.
- Storage and resource checks before installation and session creation.
- Protection against concurrent access to the same reference system.
- Multiple reference systems and explicit cleanup of abandoned sessions.
- App Sandbox support for the host application.
- Investigation of controlled networking and a VPN with fail-closed behavior.

VPN and anti-fingerprinting features are **not implemented**.

## Reference

[Apple: Running macOS in a virtual machine on Apple silicon](https://developer.apple.com/documentation/virtualization/running-macos-in-a-virtual-machine-on-apple-silicon)
