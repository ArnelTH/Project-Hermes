//
//  ContentView.swift
//  HermesApp
//
//  Created by Arnel THIOMBIANO on 07.07.2026.
//
/*
import SwiftUI
import HermesProtocol

struct ContentView: View {
    let client = HermesClient()
    
    // 🌟 Permet de savoir quand l'application s'ouvre
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        VStack(spacing: 30) {
            
            Image(systemName: "desktopcomputer")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Hermes Control")
                .font(.largeTitle)
                .bold()
            
            Button(action: {
                Task {
                    let success = await client.sendCommand(.lock)
                    if success {
                        print("🎯 Cible touchée depuis l'App !")
                    }
                }
            }) {
                Label("Verrouiller le Mac", systemImage: "lock.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        // L'écouteur du Deep Link (Si jamais tu utilises Safari ou Raccourcis)
        .onOpenURL { url in
            guard let actionString = url.host,
                  let command = CommandAction(rawValue: actionString) else { return }
            print("🔗 Deep Link reçu : \(command.rawValue) !")
            Task { let _ = await client.sendCommand(command) }
        }
        // 🌟 L'ÉCOUTEUR DE LA BOÎTE AUX LETTRES (Pour le Widget)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                checkPendingCommands()
            }
        }
    }
    
    // 🌟 La fonction qui relève le courrier
    private func checkPendingCommands() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes"),
              let commandString = sharedDefaults.string(forKey: "PendingCommand"),
              let command = CommandAction(rawValue: commandString) else {
            return
        }
        
        print("📬 Courrier du widget reçu : \(commandString) !")
        
        // On détruit la lettre pour ne pas verrouiller le Mac en boucle !
        sharedDefaults.removeObject(forKey: "PendingCommand")
        
        // On tire le paquet réseau
        Task {
            let _ = await client.sendCommand(command)
        }
    }
}
*/
import SwiftUI
import Charts
import LocalAuthentication
import HermesProtocol
internal import Combine

struct ContentView: View {
    private let client = HermesClient()
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    @State private var networkStatus = "RÉSEAU INACTIF"
    @State private var networkColor = Color.red
    @State private var batteryText = "--"
    @State private var isCharging = false
    @State private var isPinging = false
    
    @State private var isAppUnlocked = false
    @State private var biometricErrorString: String? = nil
    
    @State private var ramHistory: [Double] = Array(repeating: 0.0, count: 20)
    @State private var currentRAMString = "0.0"
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    private var dynamicBackground: Color {
        colorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground)
    }
    
    private var dynamicCardBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.white.opacity(0.04)) : AnyShapeStyle(.white)
    }
    
    private var batteryColor: Color {
        if batteryText == "--" { return .gray }
        if isCharging { return .green }
        let level = Int(batteryText.replacingOccurrences(of: "%", with: "")) ?? 100
        return level <= 20 ? .red : (colorScheme == .dark ? .white : .primary)
    }
    
    private var ramColor: Color {
            guard let lastLoad = ramHistory.last else { return .green }
            if lastLoad >= 75 { return .red }
            if lastLoad >= 50 { return .yellow }
            return .green
        }
    
    var body: some View {
        ZStack {
            dynamicBackground.edgesIgnoringSafeArea(.all)
            
            if isAppUnlocked {
                RadialGradient(gradient: Gradient(colors: [networkColor.opacity(colorScheme == .dark ? 0.08 : 0.04), .clear]), center: .top, startRadius: 10, endRadius: 600)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 28) {
                    
                    VStack(spacing: 6) {
                        Image(systemName: "macbook.and.iphone")
                            .font(.system(size: 38, weight: .ultraLight))
                            .foregroundColor(networkColor)
                            .padding(.bottom, 4)
                        
                        Text("HERMES")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .tracking(6)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: isCharging ? "battery.100.bolt" : "battery.100")
                                Text(batteryText)
                            }
                            .foregroundColor(batteryColor)
                            
                            Text("•").foregroundColor(.secondary.opacity(0.4))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                Text("\(currentRAMString)%")
                            }
                            .foregroundColor(.primary)
                        }
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .padding(.top, 24)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        DashboardCard(title: "UNLOCK", icon: "lock.open.fill", accentColor: .yellow) { authenticateAndUnlock() }
                        DashboardCard(title: "LOCK", icon: "lock.fill", accentColor: .red) { triggerAction(.lock) }
                        DashboardCard(title: "SLEEP", icon: "moon.zzz.fill", accentColor: .indigo) { triggerAction(.sleep) }
                        DashboardCard(title: "CAMERA", icon: "camera.fill", accentColor: .green) { triggerAction(.camera) }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MEMORY ACTIVITY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Chart {
                            ForEach(Array(ramHistory.enumerated()), id: \.offset) { index, value in
                                // Zone de remplissage sous la courbe
                                AreaMark(x: .value("T", index), y: .value("C", value))
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [ramColor.opacity(colorScheme == .dark ? 0.3 : 0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                // Ligne principale
                                LineMark(x: .value("T", index), y: .value("C", value))
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(ramColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.secondary.opacity(0.1))
                                AxisValueLabel() {
                                    if let intValue = value.as(Int.self) {
                                        Text("\(intValue)%").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 110)
                    }
                    .padding(18)
                    .background(dynamicCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Circle().fill(networkColor).frame(width: 6, height: 6)
                        Text(networkStatus).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                    }
                    .padding(.bottom, 16)
                }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                    
                    Text("HERMES SECURITY")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        
                    Text(biometricErrorString ?? "Authentification requise pour l'infrastructure.")
                        .font(.system(size: 13, design: .default))
                        .foregroundColor(biometricErrorString == nil ? .secondary : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                    
                    Button(action: { requestAppAccessViaFaceID() }) {
                        Text("Activer Face ID")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 28)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.top, 16)
                }
            }
        }
        .onReceive(timer) { _ in
            if scenePhase == .active && isAppUnlocked { queryTelemetry() }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if isAppUnlocked {
                    checkSharedMailbox()
                } else {
                    requestAppAccessViaFaceID()
                }
            }
        }
        .onAppear { requestAppAccessViaFaceID() }
    }
    
    // 🌟 LE CORRECTIF MAGIQUE : Le délai d'écriture SSD + Le Face ID Forcé
    private func checkSharedMailbox() {
        // On donne 0.5 secondes pour s'assurer que le widget a bien eu le temps de sauvegarder dans l'App Group
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let sharedDefaults = UserDefaults(suiteName: "group.com.arnel.hermes"),
               sharedDefaults.bool(forKey: "PendingUnlockOrder") == true {
                
                sharedDefaults.set(false, forKey: "PendingUnlockOrder")
                sharedDefaults.synchronize()
                
                // 🌟 EXIGENCE VALIDÉE : On relance Face ID spécifiquement pour la commande UNLOCK
                self.authenticateAndUnlock()
            }
        }
    }
    
    private func requestAppAccessViaFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Accès au panneau de contrôle.") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.isAppUnlocked = true }
                        self.queryTelemetry()
                        self.checkSharedMailbox()
                    } else {
                        self.biometricErrorString = "Accès refusé."
                        UserDefaults(suiteName: "group.com.arnel.hermes")?.set(false, forKey: "PendingUnlockOrder")
                    }
                }
            }
        } else {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Code de verrouillage requis.") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.isAppUnlocked = true }
                        self.queryTelemetry()
                        self.checkSharedMailbox()
                    } else {
                        self.biometricErrorString = "Authentification requise."
                        UserDefaults(suiteName: "group.com.arnel.hermes")?.set(false, forKey: "PendingUnlockOrder")
                    }
                }
            }
        }
    }
    
    private func queryTelemetry() {
        guard !isPinging else { return }
        isPinging = true
        Task {
            if let rawData = await client.sendCommand(.battery) {
                do {
                    let telemetry = try JSONDecoder().decode(HermesTelemetry.self, from: rawData)
                    networkStatus = "RÉSEAU ACTIF"
                    networkColor = .green
                    batteryText = "\(telemetry.batteryLevel)%"
                    isCharging = telemetry.isCharging
                    currentRAMString = String(format: "%.1f", telemetry.ramLoad)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        ramHistory.removeFirst()
                        ramHistory.append(telemetry.ramLoad)
                    }
                } catch {
                    networkStatus = "ERREUR TRANSMISSION"
                    networkColor = .orange
                }
            } else {
                networkStatus = "RÉSEAU INACTIF"
                networkColor = .red
                batteryText = "--"
                isCharging = false
                currentRAMString = "0.0"
            }
            isPinging = false
        }
    }
    
    private func triggerAction(_ action: CommandAction) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        Task {
            _ = await client.sendCommand(action)
            queryTelemetry()
        }
    }
    
    // 🌟 L'ACTION CRITIQUE : Demande toujours Face ID avant de transmettre
    private func authenticateAndUnlock() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Confirmez le déverrouillage distant (Action Critique).") { success, _ in
                if success { DispatchQueue.main.async { self.triggerAction(.unlock) } }
            }
        } else {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Code de verrouillage requis.") { success, _ in
                if success { DispatchQueue.main.async { self.triggerAction(.unlock) } }
            }
        }
    }
}

struct DashboardCard: View {
    let title: String
    let icon: String
    let accentColor: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.03), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
