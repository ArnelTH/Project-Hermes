// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HermesMac",
    // 1. On définit les plateformes minimales (pour utiliser les dernières API réseau)
    platforms: [
        .macOS(.v14)
    ],
    // 2. On déclare notre dépendance locale !
    // On dit à Swift : "Va chercher un package dans le dossier parent (..), qui s'appelle HermesProtocol"
    dependencies: [
        .package(path: "../HermesProtocol")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "HermesMac",
            // 3. On lie officiellement la bibliothèque à notre exécutable
            dependencies: ["HermesProtocol"]
        ),
        /*.testTarget(
            name: "HermesMacTests",
            dependencies: ["HermesMac"]
        ),*/
    ],
    //swiftLanguageModes: [.v6]
)
