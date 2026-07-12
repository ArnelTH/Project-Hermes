//
//  HermesControlWidgetBundle.swift
//  HermesControlWidget
//
//  Created by Arnel THIOMBIANO on 07.07.2026.
//

import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct HermesLockControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.lock.final") {
            ControlWidgetButton(action: ExecuteFurtiveIntent(action: .lock)) { Label("Lock Mac", systemImage: "lock.fill") }
        }
        .displayName("Lock Mac")
    }
}

@available(iOS 18.0, *)
struct HermesUnlockControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.unlock.final") {
            // 🌟 On utilise l'intention séparée ici !
            ControlWidgetButton(action: UnlockHermesIntent()) { Label("Unlock Mac", systemImage: "lock.open.fill") }
        }
        .displayName("Unlock Mac")
    }
}

@available(iOS 18.0, *)
struct HermesSleepControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.sleep.final") {
            ControlWidgetButton(action: ExecuteFurtiveIntent(action: .sleep)) { Label("Sleep", systemImage: "moon.zzz.fill") }
        }
        .displayName("Sleep Mac")
    }
}

@available(iOS 18.0, *)
struct HermesScreenshotControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.screenshot.final") {
            ControlWidgetButton(action: ExecuteFurtiveIntent(action: .screenshot)) { Label("Screenshot", systemImage: "macwindow") }
        }
        .displayName("Screenshot")
    }
}

@available(iOS 18.0, *)
struct HermesCameraControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.camera.final") {
            ControlWidgetButton(action: ExecuteFurtiveIntent(action: .camera)) { Label("Caméra", systemImage: "camera.fill") }
        }
        .displayName("Photo Sécurité")
    }
}

@available(iOS 18.0, *)
struct HermesRebootControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.reboot.final") {
            ControlWidgetButton(action: ExecuteFurtiveIntent(action: .reboot)) { Label("Reboot", systemImage: "arrow.triangle.2.circlepath") }
        }
        .displayName("Reboot Mac")
    }
}

@available(iOS 18.0, *)
struct HermesShutdownControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hermes.ctrl.shutdown.final") {
            ControlWidgetButton(action: ExecuteFurtiveIntent(action: .shutdown)) { Label("Shutdown", systemImage: "power") }
        }
        .displayName("Shutdown Mac")
    }
}

@available(iOS 18.0, *)
@main
struct HermesControlCenterBundle: WidgetBundle {
    var body: some Widget {
        HermesLockControl()
        HermesUnlockControl()
        HermesSleepControl()
        HermesScreenshotControl()
        HermesCameraControl()
        HermesRebootControl()
        HermesShutdownControl()
    }
}
