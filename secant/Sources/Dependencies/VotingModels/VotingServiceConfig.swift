import CryptoKit
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
    let proposals: [Proposal]
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

    struct Proposal: Codable, Equatable, Sendable {
        let id: Int
        let title: String
        let description: String
        let options: [Option]

        init(id: Int, title: String, description: String, options: [Option]) {
            self.id = id
            self.title = title
            self.description = description
            self.options = options
        }

        struct Option: Codable, Equatable, Sendable {
            let index: Int
            let label: String

            init(index: Int, label: String) {
                self.index = index
                self.label = label
            }
        }
    }

    init(
        configVersion: Int,
        voteRoundId: String,
        voteServers: [ServiceEndpoint],
        pirEndpoints: [ServiceEndpoint],
        snapshotHeight: UInt64,
        voteEndTime: UInt64,
        proposals: [Proposal],
        supportedVersions: SupportedVersions
    ) {
        self.configVersion = configVersion
        self.voteRoundId = voteRoundId
        self.voteServers = voteServers
        self.pirEndpoints = pirEndpoints
        self.snapshotHeight = snapshotHeight
        self.voteEndTime = voteEndTime
        self.proposals = proposals
        self.supportedVersions = supportedVersions
    }

    enum CodingKeys: String, CodingKey {
        case configVersion = "config_version"
        case voteRoundId = "vote_round_id"
        case voteServers = "vote_servers"
        case pirEndpoints = "pir_endpoints"
        case snapshotHeight = "snapshot_height"
        case voteEndTime = "vote_end_time"
        case proposals
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
        proposals: [],
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
    case proposalsHashMismatch(expected: Data, actual: Data)
    case roundIdMismatch(configRoundId: String, chainRoundId: String)

    var errorDescription: String? {
        switch self {
        case .decodeFailed(let detail):
            return String(localizable: .coinVoteConfigErrorDecodeFailed(detail))
        case .unsupportedVersion(let component, let advertised):
            return String(localizable: .coinVoteConfigErrorUnsupportedVersion(component, advertised))
        case .proposalsHashMismatch:
            return String(localizable: .coinVoteConfigErrorProposalsHashMismatch)
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

// MARK: - Proposals hash (ZIP 1244 §"Proposals Hash")

extension VotingServiceConfig {
    /// SHA-256 of the canonical JSON serialization of the proposals array.
    static func computeProposalsHash(_ proposals: [Proposal]) -> Data {
        Data(SHA256.hash(data: Data(canonicalProposalsJSON(proposals).utf8)))
    }

    /// Canonical JSON form per ZIP 1244: proposals sorted by `id` ascending, options by `index` ascending,
    /// no whitespace, keys in order `id`, `title`, `description`, `options` (and `index`, `label` for each option).
    static func canonicalProposalsJSON(_ proposals: [Proposal]) -> String {
        let sortedProposals = proposals.sorted { $0.id < $1.id }
        let parts = sortedProposals.map { proposal -> String in
            let sortedOptions = proposal.options.sorted { $0.index < $1.index }
            let optionParts = sortedOptions.map { option -> String in
                "{\"index\":\(option.index),\"label\":\(jsonEncodedString(option.label))}"
            }
            return "{\"id\":\(proposal.id),\"title\":\(jsonEncodedString(proposal.title)),\"description\":\(jsonEncodedString(proposal.description)),\"options\":[\(optionParts.joined(separator: ","))]}"
        }
        return "[\(parts.joined(separator: ","))]"
    }

    /// JSON-encode a Swift string to match the Rust `serde_json::to_string` byte output.
    /// `JSONEncoder` with `.withoutEscapingSlashes` leaves `/` un-escaped (Swift default: `\/`);
    /// otherwise defaults match serde_json (UTF-8 for non-ASCII, `\uXXXX` for control chars).
    /// The chain server computes `proposals_hash` using `serde_json`, so divergence here would
    /// cause a hard-fail `proposalsHashMismatch` any time a proposal title or label contained `/`.
    // swiftlint:disable:next force_try
    private static func jsonEncodedString(_ s: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try! encoder.encode(s)
        return String(decoding: data, as: UTF8.self)
    }
}
