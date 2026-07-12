# Projet-Hermes
Distributed macOS control infrastructure over encrypted TCP.

## Abstract
System under constraints: Sandboxed iOS environment commanding a local macOS user session. Analyzed and implemented through asynchronous system calls, inter-process communication (IPC), and E2EE cryptography. 

Designed to bypass conventional UI limitations by bridging low-level macOS Daemons with native iOS 18 Control Center widgets.

## Architecture & Constraints

### 1. macOS Daemon (Server)
* **Execution:** Unattended `LaunchAgent` running background tasks via Grand Central Dispatch (GCD).
* **Idempotent Automation:** UI manipulation via `NSAppleScript` and `System Events` (implementation of a "Spacebar Sweep" algorithm to guarantee lock-screen state reset before biometric bypass).
* **Hardware Interfacing:** Direct queries to System Management Controller (SMC) via `IOKit` for battery and memory telemetry.
* **Power Management:** Shell-level sleep prevention (`caffeinate`) during critical execution windows.

### 2. iOS 18 Client (Controller)
* **IPC Bridging:** Shared memory access via `App Groups` (`UserDefaults(suiteName:)`) to allow decoupled background widgets to trigger foreground biometric checks.
* **Lifecycle Management:** Exploitation of `scenePhase` to synchronize UI updates with daemon telemetry pulses.
* **UI/UX Design:** Parametric modeling of curves (continuous squircle) and dynamic theme shading strictly adhering to Apple Human Interface Guidelines (HIG).

### 3. Security Protocol
* **Network:** Zero-trust architecture routed through a private Tailscale mesh network.
* **Cryptography:** End-to-end payload encryption utilizing `CryptoKit` (AES-256-GCM).
* **Biometric Dual-Factor:** Mandatory `LocalAuthentication` (Face ID / Passcode) required at both app launch and specific critical payload executions.

## Engineering Notes
This project prioritizes system architecture and framework integration over low-level memory allocation (handling relies on Swift's ARC). It serves as a functional implementation of Apple's high-level networking, cryptography, and application lifecycle frameworks.
