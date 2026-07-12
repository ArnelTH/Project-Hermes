import HermesProtocol
import Foundation

@main
struct HermesMac {
    static func main() {
        print("Démarrage de l'infrastructure système...")

        // On crée notre serveur et on le démarre
        let server = HermesServer()
        server.start()

        // IMPORTANT : Sans cette ligne, un programme en ligne de commande Swift
        // exécute son code et se ferme instantanément.
        // RunLoop crée une boucle infinie qui maintient le Démon en vie, en attente d'événements.
        RunLoop.main.run()
    }
}
