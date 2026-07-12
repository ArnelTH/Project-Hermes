//
//  HermesClient.swift
//  HermesApp
//
//  Created by Arnel THIOMBIANO on 07.07.2026.
//
import Foundation
import Network
import HermesProtocol

final class HermesClient: Sendable {
    private let hostIP = "--REMPLIR ICI--"
    private let port: UInt16 = --REMPLIR ICI--
    
    // Le verrou d'accès unique (Conforme Swift 6)
    private actor RequestQueueManager {
        var isExecuting = false
        func acquireLock() -> Bool {
            if isExecuting { return false }
            isExecuting = true
            return true
        }
        func releaseLock() {
            isExecuting = false
        }
    }
    private let queueManager = RequestQueueManager()

    func sendCommand(_ action: CommandAction) async -> Data? {
        let accessGranted = await queueManager.acquireLock()
        guard accessGranted else { return nil }
        
        let responseData = await performSingleShotNetworkCall(action)
        
        await queueManager.releaseLock()
        return responseData
    }
    
    private func performSingleShotNetworkCall(_ action: CommandAction) async -> Data? {
        let continuationManager = ContinuationManager()
        
        return await withCheckedContinuation { continuation in
            // 🌟 LE CORRECTIF VITAL POUR LE .local : Autoriser le Peer-to-Peer
            let tlsOptions = NWProtocolTLS.Options()
            let secOptions = tlsOptions.securityProtocolOptions
            
            let secretKeyString = "HERMES_QUANTUM_KEY_2026_SECURE!@#"
            let identityString = "HermesClient"
            
            let pskData = secretKeyString.data(using: .utf8)!
            let pskIdentityData = identityString.data(using: .utf8)!
            
            let dispatchPsk = pskData.withUnsafeBytes { DispatchData(bytes: $0) }
            let dispatchIdentity = pskIdentityData.withUnsafeBytes { DispatchData(bytes: $0) }
            
            sec_protocol_options_add_pre_shared_key(secOptions, dispatchPsk as dispatch_data_t, dispatchIdentity as dispatch_data_t)
            
            sec_protocol_options_set_verify_block(secOptions, { _, _, completion in
                completion(true)
                        }, .global())
            
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            
            let endpointPort = NWEndpoint.Port(rawValue: port)!
            let connection = NWConnection(host: NWEndpoint.Host(hostIP), port: endpointPort, using: params)
            let actionString = action.rawValue
            
            // Le chronomètre de secours (4 secondes)
            let watchdogTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if !Task.isCancelled {
                    // On annule proprement sans toucher au handler
                    connection.cancel()
                    await continuationManager.resume(continuation, with: nil)
                }
            }
            
                        
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard let rawPayload = actionString.data(using: .utf8),
                          // 🌟 CHIFFREMENT DE LA COMMANDE
                          let encryptedPayload = HermesCrypto.encrypt(rawPayload) else { return }
                    
                    let header = HermesHeader(
                        type: .command,
                        length: UInt32(encryptedPayload.count), // Taille cryptée
                        timestamp: UInt64(Date().timeIntervalSince1970),
                        nonce: UInt64.random(in: 1...100000)
                    )
                    let message = HermesMessage(header: header, payload: encryptedPayload)
                    
                    connection.send(content: message.encode(), completion: .contentProcessed({ error in
                        if error != nil {
                            watchdogTask.cancel()
                            connection.stateUpdateHandler = nil
                            connection.cancel()
                            Task { await continuationManager.resume(continuation, with: nil) }
                            return
                        }
                        
                        let headerSize = MemoryLayout<HermesHeader>.size
                        
                        connection.receive(minimumIncompleteLength: headerSize, maximumLength: headerSize) { headerData, _, _, error in
                            guard let headerData = headerData, headerData.count == headerSize, error == nil,
                                  let responseHeader = HermesHeader(data: headerData) else {
                                watchdogTask.cancel()
                                connection.stateUpdateHandler = nil
                                connection.cancel()
                                Task { await continuationManager.resume(continuation, with: nil) }
                                return
                            }
                            
                            let payloadLength = Int(responseHeader.length)
                            if payloadLength > 0 {
                                connection.receive(minimumIncompleteLength: payloadLength, maximumLength: payloadLength) { payloadData, _, _, error in
                                    watchdogTask.cancel()
                                    connection.stateUpdateHandler = nil
                                    connection.cancel()
                                    
                                    // 🌟 DÉCHIFFREMENT DU JSON REÇU
                                    if let payloadData = payloadData, payloadData.count == payloadLength, error == nil,
                                       let decryptedData = HermesCrypto.decrypt(payloadData) {
                                        Task { await continuationManager.resume(continuation, with: decryptedData) }
                                    } else {
                                        Task { await continuationManager.resume(continuation, with: nil) }
                                    }
                                }
                            } else {
                                watchdogTask.cancel()
                                connection.stateUpdateHandler = nil
                                connection.cancel()
                                Task { await continuationManager.resume(continuation, with: Data()) }
                            }
                        }
                    }))
                case .failed(_), .cancelled:
                    watchdogTask.cancel()
                    Task { await continuationManager.resume(continuation, with: nil) }
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }
}

actor ContinuationManager {
    private var didResume = false
    func resume(_ continuation: CheckedContinuation<Data?, Never>, with value: Data?) {
        if !didResume {
            didResume = true
            continuation.resume(returning: value)
        }
    }
}
