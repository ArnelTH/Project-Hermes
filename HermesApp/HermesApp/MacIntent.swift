//
//  MacIntent.swift
//  HermesApp
//
//  Created by Arnel THIOMBIANO on 07.07.2026.
//

import AppIntents
import Foundation

// 1. Verrouillage
struct LockMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Verrouiller"
    static var openAppWhenRun: Bool = true
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes") {
            sharedDefaults.set("LOCK", forKey: "PendingCommand")
        }
        return .result()
    }
}

// 2. Verrouillage
struct UnLockMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Déverrouiller"
    static var openAppWhenRun: Bool = true
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes") {
            sharedDefaults.set("UNLOCK", forKey: "PendingCommand")
        }
        return .result()
    }
}

// 3. Mise en veille
struct SleepMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Veille"
    static var openAppWhenRun: Bool = true
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes") {
            sharedDefaults.set("SLEEP", forKey: "PendingCommand")
        }
        return .result()
    }
}

// 3. Capture d'écran
struct ScreenshotMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture"
    static var openAppWhenRun: Bool = true
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes") {
            sharedDefaults.set("SCREENSHOT", forKey: "PendingCommand")
        }
        return .result()
    }
}

// 4. Batterie
struct BatteryMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Batterie"
    static var openAppWhenRun: Bool = true
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes") {
            sharedDefaults.set("BATTERY", forKey: "PendingCommand")
        }
        return .result()
    }
}
