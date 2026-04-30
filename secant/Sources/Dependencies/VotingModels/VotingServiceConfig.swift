import Foundation

/// CDN-hosted voting service configuration as specified in ZIP 1244 §"Vote Configuration Format".
///
/// A JSON document published per voting round; fetched at startup from `configURL`.
/// A debug-only local override (`localOverrideFilename` in the app bundle) takes priority for testing.
struct VotingServiceConfig: Codable, Equatable, Sendable {
    let configVersion: Int
    let voteRoundId: String
    let voteServers: [ServiceEndpoint]
    let pirEndpoints: [ServiceEndpoint]
    let snapshotHeight: UInt64
    let voteEndTime: UInt64
    let supportedVersions: SupportedVersions

    struct ServiceEndpoint: Codable, Equatable, Sendable {
        let url: String
        let label: String

        init(url: String, label: String) {
            self.url = url
            self.label = label
        }
    }

    struct SupportedVersions: Codable, Equatable, Sendable {
        let pir: [String]
        let voteProtocol: String
        let tally: String
        let voteServer: String

        init(pir: [String], voteProtocol: String, tally: String, voteServer: String) {
            self.pir = pir
            self.voteProtocol = voteProtocol
            self.tally = tally
            self.voteServer = voteServer
        }

        enum CodingKeys: String, CodingKey {
            case pir
            case voteProtocol = "vote_protocol"
            case tally
            case voteServer = "vote_server"
        }
    }

    init(
        configVersion: Int,
        voteRoundId: String,
        voteServers: [ServiceEndpoint],
        pirEndpoints: [ServiceEndpoint],
        snapshotHeight: UInt64,
        voteEndTime: UInt64,
        supportedVersions: SupportedVersions
    ) {
        self.configVersion = configVersion
        self.voteRoundId = voteRoundId
        self.voteServers = voteServers
        self.pirEndpoints = pirEndpoints
        self.snapshotHeight = snapshotHeight
        self.voteEndTime = voteEndTime
        self.supportedVersions = supportedVersions
    }

    enum CodingKeys: String, CodingKey {
        case configVersion = "config_version"
        case voteRoundId = "vote_round_id"
        case voteServers = "vote_servers"
        case pirEndpoints = "pir_endpoints"
        case snapshotHeight = "snapshot_height"
        case voteEndTime = "vote_end_time"
        case supportedVersions = "supported_versions"
    }

    /// Config URL served via GitHub Pages CDN.
    public static let configURL = URL(string: "https://valargroup.github.io/token-holder-voting-config/voting-config.json")!

    /// Filename for a local override bundled in the app (debug-only).
    static let localOverrideFilename = "voting-config-local.json"

    #if DEBUG
    /// Debug-only config used by previews and tests. Not used on the live path —
    /// a CDN fetch or decode failure surfaces as a `VotingConfigError` instead.
    static let debugFallback = VotingServiceConfig(
        configVersion: 1,
        voteRoundId: String(repeating: "0", count: 64),
        voteServers: [ServiceEndpoint(url: "https://vote-chain-primary.valargroup.org", label: "Primary")],
        pirEndpoints: [ServiceEndpoint(url: "https://pir.valargroup.org", label: "PIR Server")],
        snapshotHeight: 0,
        voteEndTime: 0,
        supportedVersions: SupportedVersions(
            pir: ["v0"],
            voteProtocol: "v0",
            tally: "v0",
            voteServer: "v1"
        )
    )
    #endif
}

// MARK: - Wallet capabilities

/// Versions of each voting-protocol component this wallet build can handle.
/// Values MUST reflect what the app (including `VotingRustBackend`) actually implements —
/// not what it aspires to — or the wallet will reject valid configs and lock users out.
enum WalletCapabilities {
    static let voteServer: Set<String> = ["v1"]
    static let voteProtocol: Set<String> = ["v0"]
    static let tally: Set<String> = ["v0"]
    static let pir: Set<String> = ["v0"]
}

// MARK: - Errors

enum VotingConfigError: Error, Equatable, LocalizedError {
    case decodeFailed(String)
    case unsupportedVersion(component: String, advertised: String)
    case roundIdMismatch(configRoundId: String, chainRoundId: String)

    var errorDescription: String? {
        switch self {
        case .decodeFailed(let detail):
            return String(localizable: .coinVoteConfigErrorDecodeFailed(detail))
        case .unsupportedVersion(let component, let advertised):
            return String(localizable: .coinVoteConfigErrorUnsupportedVersion(component, advertised))
        case .roundIdMismatch(let configRoundId, let chainRoundId):
            return String(
                localizable: .coinVoteConfigErrorRoundIdMismatch(
                    String(configRoundId.prefix(16)),
                    String(chainRoundId.prefix(16))
                )
            )
        }
    }
}

// MARK: - Validation (ZIP 1244 §"Version Handling")

extension VotingServiceConfig {
    /// Throws `VotingConfigError.unsupportedVersion` on the first component the wallet doesn't support.
    func validate() throws {
        if !WalletCapabilities.voteServer.contains(supportedVersions.voteServer) {
            throw VotingConfigError.unsupportedVersion(
                component: "vote_server",
                advertised: supportedVersions.voteServer
            )
        }
        if !WalletCapabilities.voteProtocol.contains(supportedVersions.voteProtocol) {
            throw VotingConfigError.unsupportedVersion(
                component: "vote_protocol",
                advertised: supportedVersions.voteProtocol
            )
        }
        if !WalletCapabilities.tally.contains(supportedVersions.tally) {
            throw VotingConfigError.unsupportedVersion(
                component: "tally",
                advertised: supportedVersions.tally
            )
        }
        if WalletCapabilities.pir.isDisjoint(with: supportedVersions.pir) {
            throw VotingConfigError.unsupportedVersion(
                component: "pir",
                advertised: supportedVersions.pir.joined(separator: ",")
            )
        }
    }
}
