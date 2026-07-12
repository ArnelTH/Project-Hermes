//
//  HermesIntents.swift.swift
//  HermesApp
//
//  Created by Arnel THIOMBIANO on 08.07.2026.
//

import Foundation
import AppIntents
import HermesProtocol

public enum HermesFurtiveAction: String, AppEnum {
    case lock = "LOCK"
    case sleep = "SLEEP"
    case shutdown = "SHUTDOWN"
    case reboot = "REBOOT"
    case screenshot = "SCREENSHOT"
    case camera = "CAMERA"
    
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Commande Furtive"
    public static var caseDisplayRepresentations: [HermesFurtiveAction: DisplayRepresentation] = [
        .lock: "🔒 Verrouiller le Mac",
        .sleep: "🌙 Mettre en veille",
        .shutdown: "🛑 Éteindre",
        .reboot: "🔄 Redémarrer",
        .screenshot: "🖥️ Capture d'écran",
        .camera: "📸 Photo de sécurité"
    ]
}

struct ExecuteFurtiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Commande Furtive"
    
    @Parameter(title: "Action")
    var action: HermesFurtiveAction

    init() {}
    init(action: HermesFurtiveAction) { self.action = action }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let command = CommandAction(rawValue: action.rawValue) else { return .result(value: "Erreur") }
        let client = HermesClient()
        let result = await client.sendCommand(command)
        return .result(value: result != nil ? "Transmis 🟢" : "Échec réseau 🔴")
    }
}

struct UnlockHermesIntent: AppIntent {
    static var title: LocalizedStringResource = "🔓 Déverrouiller le Mac"
    static var openAppWhenRun: Bool = true
    
    init() {}

    func perform() async throws -> some IntentResult {
        // 🌟 Dépôt dans le vrai conteneur partagé validé
        if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes") {
            sharedDefaults.set(true, forKey: "PendingUnlockOrder")
            sharedDefaults.synchronize()
        }
        return .result()
    }
}
