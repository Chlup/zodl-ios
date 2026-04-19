import Foundation

/// CDN-hosted config listing vote servers and PIR servers.
/// Fetched at startup from `VotingServiceConfig.configURL`.
/// A local override file (`voting-config-local.json` in the app bundle) takes priority
/// to simplify testing against a local chain.
struct VotingServiceConfig: Codable, Equatable, Sendable {
    let version: Int
    let voteServers: [ServiceEndpoint]
    let pirServers: [ServiceEndpoint]

    struct ServiceEndpoint: Codable, Equatable, Sendable {
        let url: String
        let label: String

        init(url: String, label: String) {
            self.url = url
            self.label = label
        }
    }

    init(version: Int, voteServers: [ServiceEndpoint], pirServers: [ServiceEndpoint]) {
        self.version = version
        self.voteServers = voteServers
        self.pirServers = pirServers
    }

    enum CodingKeys: String, CodingKey {
        case version
        case voteServers = "vote_servers"
        case pirServers = "pir_servers"
    }

    /// Config URL served via GitHub Pages CDN.
    public static let configURL = URL(string: "https://valargroup.github.io/token-holder-voting-config/voting-config.json")!

    /// Filename for a local override bundled in the app (takes priority over CDN).
    static let localOverrideFilename = "voting-config-local.json"

    /// Default config used when both local override and CDN are unavailable.
    /// Points at the deployed dev server so TestFlight builds work without CDN.
    static let fallback = VotingServiceConfig(
        version: 1,
        voteServers: [ServiceEndpoint(url: "https://46-101-255-48.sslip.io", label: "Primary")],
        pirServers: [ServiceEndpoint(url: "https://46-101-255-48.sslip.io/nullifier", label: "PIR Server")]
    )
}
