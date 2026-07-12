import Foundation
import Network
import HermesProtocol

import Foundation
import Network
import HermesProtocol
import AppKit // 🌟 Requis pour NSWorkspace

// 🌟 LE DÉTECTEUR DE CONNEXION (Alarme)
final class SessionMonitor: Sendable {
    static let shared = SessionMonitor()

    // Remplace par un nom de canal UNIQUE et secret
    private let ntfyTopic = "--REMPLIR ICI--"

    private init() {}

    func startMonitoring() {
        // 🌟 Le canal radio système (DistributedNotificationCenter)
        // Contrairement à NSWorkspace, ce canal est audible par les LaunchAgents
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            self.sendPushNotification()
        }

        print("🛡️ Moniteur de session (Système) armé. En attente de déverrouillage...")
    }

    private func sendPushNotification() {
        // 🌟 Remplace par TES codes Telegram
        let botToken = "--REMPLIR ICI--"
        let chatId = "--REMPLIR ICI--"

        guard let url = URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let message = "🚨 *ALERTE INTRUSION*\nLa session du Mac vient d'être déverrouillée !"

        let body: [String: Any] = [
            "chat_id": chatId,
            "text": message,
            "parse_mode": "Markdown" // Permet de mettre en gras/italique
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("🔴 Échec Telegram : \(error)")
            } else {
                print("🟢 Alarme Telegram expédiée à la vitesse de la lumière !")
            }
        }.resume()
    }
}


final class HermesServer: @unchecked Sendable {
    private let listener: NWListener
    private let port: NWEndpoint.Port = --REMPLIR ICI--

    init() {
        self.listener = try! NWListener(using: .tcp, on: port)
    }

    private static func buildTLSOptions() -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions

        // Notre clé maître secrète partagée (À ne jamais divulguer)
        let secretKeyString = "--REMPLIR ICI--"
        let identityString = "HermesClient"

        // Conversion en DispatchData pour l'API C de BoringSSL
        let pskData = secretKeyString.data(using: .utf8)!
        let pskIdentityData = identityString.data(using: .utf8)!

        let dispatchPsk = pskData.withUnsafeBytes { DispatchData(bytes: $0) }
        let dispatchIdentity = pskIdentityData.withUnsafeBytes { DispatchData(bytes: $0) }

        // Injection de la clé dans la RAM pour le chiffrement TLS
        sec_protocol_options_add_pre_shared_key(secOptions, dispatchPsk as dispatch_data_t, dispatchIdentity as dispatch_data_t)

        // On force le serveur à accepter la connexion sans certificat classique
        sec_protocol_options_set_verify_block(secOptions, { _, _, completion in
            completion(true)
        }, .global())

        return tlsOptions
    }

    func start() {
        // 🌟 Démarrage du moniteur d'alarme en même temps que le serveur TCP
        SessionMonitor.shared.startMonitoring()
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("🟢 Démon Hermes en écoute active et sécurisée sur le port 8080...")
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        listener.start(queue: .main)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        self.readNextPacket(on: connection)
    }

    private func readNextPacket(on connection: NWConnection) {
        let headerSize = MemoryLayout<HermesHeader>.size

        // 🌟 ÉTAPE 1 : On extrait d'abord l'en-tête de manière isolée
        connection.receive(minimumIncompleteLength: headerSize, maximumLength: headerSize) { headerData, _, isComplete, error in
            guard let headerData = headerData, headerData.count == headerSize, error == nil else {
                connection.stateUpdateHandler = nil
                connection.cancel()
                return
            }

            if let header = HermesHeader(data: headerData) {
                let payloadLength = Int(header.length)

                if payloadLength > 0 {
                    connection.receive(minimumIncompleteLength: payloadLength, maximumLength: payloadLength) { payloadData, _, _, error in
                        guard let payloadData = payloadData, payloadData.count == payloadLength, error == nil else {
                            connection.stateUpdateHandler = nil
                            connection.cancel()
                            return
                        }

                        // 🌟 DÉCHIFFREMENT AES-256 DU MESSAGE ENTRANT
                        guard let decryptedData = HermesCrypto.decrypt(payloadData),
                        let actionString = String(data: decryptedData, encoding: .utf8) else {
                            print("🔴 ALERTE SÉCURITÉ : Paquet corrompu ou non autorisé intercepté.")
                            connection.stateUpdateHandler = nil
                            connection.cancel()
                            return
                        }

                        let cleanAction = actionString.trimmingCharacters(in: .controlCharacters).replacingOccurrences(of: "\0", with: "")

                        if let action = CommandAction(rawValue: cleanAction) {
                            print("🚀 Action décryptée et validée : \(action.rawValue)")

                            let executor = HermesExecutor()
                            if let responsePayload = executor.execute(action: action),
                               // 🌟 CHIFFREMENT AES-256 DE LA RÉPONSE (La télémétrie JSON)
                                let encryptedResponse = HermesCrypto.encrypt(responsePayload) {

                                let responseHeader = HermesHeader(
                                    type: .response,
                                    length: UInt32(encryptedResponse.count),
                                    timestamp: UInt64(Date().timeIntervalSince1970),
                                    nonce: header.nonce + 1
                                )

                                let responseMessage = HermesMessage(header: responseHeader, payload: encryptedResponse)

                                connection.send(content: responseMessage.encode(), completion: .contentProcessed({ _ in
                                    connection.stateUpdateHandler = nil
                                    connection.cancel()
                                }))
                                return
                            }
                        }
                        connection.stateUpdateHandler = nil
                        connection.cancel()
                    }
                } else {
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                }
            } else {
                connection.stateUpdateHandler = nil
                connection.cancel()
            }
        }
    }
}
