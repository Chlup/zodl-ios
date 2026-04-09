// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "modules",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Dummy", targets: ["Dummy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", "1.25.4"..<"1.26.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", "1.9.0"..<"1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", "1.7.2"..<"1.8.0"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", "0.6.2"..<"0.7.0"),
        .package(url: "https://github.com/zcash-hackworks/MnemonicSwift", "2.2.5"..<"2.3.0"),
        .package(url: "https://github.com/zcash/zcash-swift-wallet-sdk", "2.4.9"..<"2.5.0"),
        .package(url: "https://github.com/flexa/flexa-ios.git", "1.1.4"..<"1.2.0"),
        .package(url: "https://github.com/pacu/zcash-swift-payment-uri", "1.0.1"..<"1.1.0"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", "4.6.0"..<"4.7.0"),
        .package(url: "https://github.com/KeystoneHQ/keystone-sdk-ios/", "0.8.6"..<"0.9.0"),
        .package(url: "https://github.com/mgriebling/BigDecimal.git", exact: "2.2.3"),
        .package(url: "https://github.com/mgriebling/UInt128.git", exact: "3.1.5"),
        .package(url: "https://github.com/liamnichols/xcstrings-tool-plugin", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "Dummy",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "ZcashLightClientKit", package: "zcash-swift-wallet-sdk"),
                .product(name: "KeystoneSDK", package: "keystone-sdk-ios"),
                .product(name: "URLRouting", package: "swift-url-routing"),
                .product(name: "Flexa", package: "flexa-ios"),
                .product(name: "MnemonicSwift", package: "MnemonicSwift"),
                .product(name: "ZcashPaymentURI", package: "zcash-swift-payment-uri"),
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "BigDecimal", package: "BigDecimal"),
                .product(name: "UInt128", package: "UInt128")
            ],
            path: "Dummy",
            plugins: [
                .plugin(name: "XCStringsToolPlugin", package: "xcstrings-tool-plugin")
            ]
        )
    ]
)
