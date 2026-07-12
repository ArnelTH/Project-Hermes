import Foundation
import HermesProtocol
import IOKit.ps
import Darwin
import AVFoundation

import Foundation
import HermesProtocol
import IOKit.ps
import Darwin
import AVFoundation // 🌟 Requis pour piloter la caméra physique

// Classe utilitaire pour capturer la webcam de manière asynchrone sans UI
final class CameraCaptureEngine: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var session: AVCaptureSession?
    private var output: AVCapturePhotoOutput?
    private let completion: (Data?) -> Void
    private var retainSelf: CameraCaptureEngine?

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
        super.init()
    }

    func takePhoto() {
        self.retainSelf = self

        guard let device = AVCaptureDevice.default(for: .video) else {
            print("🔴 Aucun capteur vidéo physique trouvé sur ce Mac.")
            completion(nil)
            self.retainSelf = nil
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()
            let output = AVCapturePhotoOutput()

            if session.canAddInput(input) && session.canAddOutput(output) {
                session.addInput(input)
                session.addOutput(output)
                session.startRunning()

                self.session = session
                self.output = output

                // 🌟 Sécurité de synchronisation : On laisse 300ms au capteur pour s'initialiser
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let settings = AVCapturePhotoSettings()
                    output.capturePhoto(with: settings, delegate: self)
                }
            } else {
                print("🔴 Impossible d'associer les flux d'entrée/sortie à la session de capture.")
                completion(nil)
                self.retainSelf = nil
            }
        } catch {
            print("🔴 Erreur d'initialisation matérielle : \(error.localizedDescription)")
            completion(nil)
            self.retainSelf = nil
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        session?.stopRunning()

        // 🌟 Vérification d'une erreur de capture native d'Apple
        if let error = error {
            print("🔴 Le capteur a retourné une erreur lors de la capture : \(error.localizedDescription)")
            completion(nil)
        } else if let data = photo.fileDataRepresentation() {
            completion(data)
        } else {
            completion(nil)
        }
        self.retainSelf = nil
    }
}

// Dans ton HermesExecutor.swift, mets à jour le cas de capture :
// (Exemple d'intégration asynchrone dans le switch action)

// 🌟 1. LE NOUVEAU MOTEUR DE MÉMOIRE VIVE (RAM)
final class RAMMonitor: @unchecked Sendable {
    static let shared = RAMMonitor()

    func getLoad() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result != KERN_SUCCESS { return 0.0 }

        // Extraction de la RAM totale du Mac
        var mib = [CTL_HW, HW_MEMSIZE]
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctl(&mib, 2, &totalMemory, &size, nil, 0)

        let pageSize = UInt64(getpagesize())
        let active = UInt64(stats.active_count) * pageSize
        let wire = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        let usedMemory = Double(active + wire + compressed)
        let total = Double(totalMemory)

        if total == 0 { return 0.0 }
        return (usedMemory / total) * 100.0
    }
}

final class HermesExecutor: @unchecked Sendable {

    func execute(action: CommandAction) -> Data? {
        switch action {
        case .lock:
            // 🌟 2. EXÉCUTION ASYNCHRONE : Le Mac répond "OK" direct, et verrouille en arrière-plan !
            DispatchQueue.global(qos: .userInitiated).async {
                self.runShell("osascript -e 'tell application \"System Events\" to keystroke \"q\" using {control down, command down}'")
            }
            return "OK".data(using: .utf8)

        case .unlock:
            print("🔓 Tentative de déverrouillage...")
            guard let password = getOrPromptLocalPassword() else {
                return "ERR_NO_PWD".data(using: .utf8)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                // On utilise le terminal (zsh) qui fonctionnait, avec injection directe du script
                let shellCommand = """
                caffeinate -u -t 2 &
                sleep 0.8
                osascript <<EOF
                tell application "System Events"
                    keystroke " "
                    delay 0.5
                    keystroke "a" using command down
                    delay 0.1
                    key code 51
                    delay 0.1
                    keystroke "\(password)"
                    delay 0.1
                    keystroke return
                end tell
                EOF
                """
                self.runShell(shellCommand)
            }
            return "OK".data(using: .utf8)

        case .sleep:
            DispatchQueue.global(qos: .userInitiated).async { self.runShell("pmset sleepnow") }
            return "OK".data(using: .utf8)

        case .shutdown:
            DispatchQueue.global(qos: .userInitiated).async { self.runShell("osascript -e 'tell application \"System Events\" to shut down'") }
            return "OK".data(using: .utf8)

        case .reboot:
            DispatchQueue.global(qos: .userInitiated).async { self.runShell("osascript -e 'tell application \"System Events\" to restart'") }
            return "OK".data(using: .utf8)

        case .screenshot:
            DispatchQueue.global(qos: .userInitiated).async {
                let timestamp = Int(Date().timeIntervalSince1970)
                let path = "~/Desktop/Hermes_Capture_\(timestamp).png"
                self.runShell("screencapture -x \(path)")
            }
            return "OK".data(using: .utf8)

        case .camera:
            print("📸 Déclenchement de la caméra de sécurité native...")

            DispatchQueue.main.async {
                let cameraEngine = CameraCaptureEngine { photoData in
                    guard let data = photoData else {
                        print("🔴 Échec : Les données de la photo sont vides.")
                        return
                    }

                    // 🌟 On écrit dans /tmp/ pour contourner temporairement le blocus TCC du Bureau
                    let targetURL = URL(fileURLWithPath: "/tmp/Hermes_Capture.jpg")

                    do {
                        try data.write(to: targetURL)
                        print("🟢 PHOTO ENREGISTRÉE AVEC SUCCÈS ICI ➔ \(targetURL.path)")

                        // Tentative de copie sur le Bureau pour tester le blocus TCC
                        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Desktop")
                            .appendingPathComponent("Hermes_Cam_\(Int(Date().timeIntervalSince1970)).jpg")

                        try? data.write(to: desktopURL)

                    } catch {
                        print("🔴 Échec critique de l'écriture sur le disque : \(error.localizedDescription)")
                    }
                }
                cameraEngine.takePhoto()
            }
            return "OK".data(using: .utf8)

        case .battery:
            let battery = getBatteryData()
            let ram = RAMMonitor.shared.getLoad()

            // 🌟 On intègre la RAM dans la télémétrie
            let telemetry = HermesTelemetry(batteryLevel: battery.level, isCharging: battery.status, ramLoad: ram)
            return try? JSONEncoder().encode(telemetry)

        }
    }

    private func getOrPromptLocalPassword() -> String? {
        let defaults = UserDefaults.standard
        if let savedPassword = defaults.string(forKey: "HermesLocalSecureKey") { return savedPassword }

        let script = """
        set pwd to text returned of (display dialog "HERMES SETUP : Saisissez le mot de passe de session de ce Mac pour lier la clé biométrique FaceID de votre iPhone." default answer "" with hidden answer with title "Initialisation de sécurité")
        return pwd
        """
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            defaults.set(output, forKey: "HermesLocalSecureKey")
            return output
        }
        return nil
    }

    private func getBatteryData() -> (level: Int, status: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        if let source = sources.first,
            let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
            let capacity = description["Current Capacity"] as? Int {
            let isCharging = description["Is Charging"] as? Bool ?? false
            return (capacity, isCharging)
        }
        return (100, false)
    }

    private func runShell(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        try? process.run()
    }
}
