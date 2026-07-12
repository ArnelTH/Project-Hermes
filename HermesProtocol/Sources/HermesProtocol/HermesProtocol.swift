import Foundation // Importe les types de base d'Apple (comme UInt32, Data, etc.)
import CryptoKit// 🌟 Le framework de cryptographie natif d'Apple

// 1. Notre énumération pour les types de messages
// Le "public" est indispensable ! Comme c'est une bibliothèque (library),
// on doit dire explicitement quelles parties sont visibles pour le Mac et l'iPhone.
public enum MessageType: UInt16 {
    case command = 1
    case response = 2
    case event = 3
    case error = 4
}

// 2. Notre en-tête strict (Header)
public struct HermesHeader: Sendable {
  // Le "Magic Number" permet au Mac de vérifier instantanément
  // que le message provient bien de notre application et pas d'un scanneur aléatoire sur le réseau.
  // 0x48524D53 correspond aux lettres "HRMS" en hexadécimal !
    public let magic: UInt32

    public let version: UInt16
    public let type: UInt16
    public let length: UInt32
    public let timestamp: UInt64
    public let nonce: UInt64

  // Un initialiseur (comme un constructeur) pour créer notre Header facilement
    public init(version: UInt16 = 1, type: MessageType, length: UInt32, timestamp: UInt64, nonce: UInt64) {
    self.magic = 0x48524D53
    self.version = version
    self.type = type.rawValue // On extrait le "1", "2" ou "3" de l'énumération
    self.length = length
    self.timestamp = timestamp
    self.nonce = nonce
    }
}

// Notre énumération stricte des commandes possibles (le Payload)
public enum CommandAction: String, Codable, Sendable {
    case lock = "LOCK"
    case sleep = "SLEEP"
    case shutdown = "SHUTDOWN"
    case reboot = "REBOOT"
    case battery = "BATTERY"
    case screenshot = "SCREENSHOT"
    case camera = "CAMERA"
    case unlock = "UNLOCK"

    // Si tu veux, tu peux ajouter les autres plus tard (WIFI, CPU, RAM...)
}

// 🌟 La structure standardisée pour l'échange de télémétrie
public struct HermesTelemetry: Codable, Sendable {
    public let batteryLevel: Int
    public let isCharging: Bool
    public let ramLoad: Double

    public init(batteryLevel: Int, isCharging: Bool, ramLoad: Double) {
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.ramLoad = ramLoad
    }
}

// Le paquet complet qui transitera sur le réseau
public struct HermesMessage: Sendable {
    public let header: HermesHeader
    public let payload: Data
    public let signature: Data

    // L'initialiseur
    // Astuce Swift : En écrivant "= Data()", on donne une valeur par défaut (vide).
    // Si on veut envoyer un message sans corps, on n'aura même pas besoin de préciser le paramètre ! C'est l'expressivité.
    public init(header: HermesHeader, payload: Data = Data(), signature: Data = Data()) {
        self.header = header
        self.payload = payload
        self.signature = signature
    }
}


// On étend notre structure pour lui ajouter des capacités de sérialisation
extension HermesMessage {

  // Cette fonction transforme notre bel objet Swift en un bloc d'octets bruts (Data)
    public func encode() -> Data {
    var data = Data()

    // 1. On sérialise le Header (Attention : c'est une technique simplifiée pour démarrer)
    // withUnsafeBytes permet de lire la mémoire brute (les bits) de notre struct Header
    var headerCopy = self.header
    let headerData = withUnsafeBytes(of: &headerCopy) { Data($0) }
    data.append(headerData)

    // 2. On ajoute le corps (qui est déjà en type Data)
    data.append(self.payload)

    // 3. On ajoute la signature (déjà en type Data)
    data.append(self.signature)

    return data
    }
}

extension HermesHeader {

    // Un initialiseur optionnel (le "?" veut dire qu'il peut échouer et renvoyer nil si les données sont corrompues)
    public init?(data: Data) {

        // 1. On vérifie qu'on a reçu assez d'octets pour remplir un en-tête complet.
        // MemoryLayout calcule dynamiquement la taille exacte de ta struct (avec les paddings)
        let headerSize = MemoryLayout<HermesHeader>.size
        guard data.count >= headerSize else { return nil }

        // 2. On extrait juste les octets correspondants à l'en-tête (on laisse le Payload pour plus tard)
        let headerData = data.prefix(headerSize)

        // 3. Le moulage ! On copie les octets bruts directement dans les variables de notre structure
        let decodedHeader = headerData.withUnsafeBytes { pointeurBrut in
            pointeurBrut.load(as: HermesHeader.self)
        }

        // 4. LE BOUNCER (Le Vigile) : C'est la sécurité de base de notre protocole.
        // Si le Magic Number n'est pas "HRMS", on rejette le paquet direct.
        guard decodedHeader.magic == 0x48524D53 else {
            return nil
        }

        // Si tout est bon, on s'initialise avec ces valeurs !
        self = decodedHeader
    }
}


// 🌟 LE MOTEUR AES-256-GCM
@available(macOS 10.15, iOS 13.0, *)
public struct HermesCrypto: Sendable {
    // Clé maître de 32 octets (256 bits)
    // À garder secrète. Elle doit être identique sur le Mac et l'iPhone.
    private static let rawKey = "HERMES_QUANTUM_KEY_2026_SECURE!!"
    private static let symmetricKey = SymmetricKey(data: rawKey.data(using: .utf8)!)

    // Verrouillage
    public static func encrypt(_ payload: Data) -> Data? {
        // AES-GCM génère automatiquement un nonce (vecteur d'initialisation) et un tag d'authenticité
        try? AES.GCM.seal(payload, using: symmetricKey).combined
    }

    // Déverrouillage
    public static func decrypt(_ combinedData: Data) -> Data? {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: combinedData) else { return nil }
        return try? AES.GCM.open(sealedBox, using: symmetricKey)
    }
}
