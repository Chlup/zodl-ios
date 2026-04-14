import ComposableArchitecture
import Foundation

// MARK: - Share Status Types

/// Result of polling a helper server for share confirmation status.
enum ShareConfirmationResult: Equatable, Sendable {
    case pending
    case confirmed
}

/// Info about which servers accepted a delegated share.
struct DelegatedShareInfo: Equatable, Sendable {
    let shareIndex: UInt32
    let proposalId: UInt32
    let acceptedByServers: [String]

    init(shareIndex: UInt32, proposalId: UInt32, acceptedByServers: [String]) {
        self.shareIndex = shareIndex
        self.proposalId = proposalId
        self.acceptedByServers = acceptedByServers
    }
}

extension DependencyValues {
    var votingAPI: VotingAPIClient {
        get { self[VotingAPIClient.self] }
        set { self[VotingAPIClient.self] = newValue }
    }
}

@DependencyClient
struct VotingAPIClient {
    /// Fetch service config: tries local override first, then CDN, then falls back to defaults.
    var fetchServiceConfig: @Sendable () async throws -> VotingServiceConfig
    /// Configure the API client to use URLs from the resolved service config.
    var configureURLs: @Sendable (_ config: VotingServiceConfig) async -> Void
    var fetchActiveVotingSession: @Sendable () async throws -> VotingSession
    var fetchAllRounds: @Sendable () async throws -> [VotingSession]
    var fetchRoundById: @Sendable (_ roundIdHex: String) async throws -> VotingSession
    var fetchTallyResults: @Sendable (_ roundIdHex: String) async throws -> [UInt32: TallyResult]
    var fetchVotingWeight: @Sendable (_ snapshotHeight: UInt64) async throws -> UInt64
    var fetchNoteInclusionProofs: @Sendable (_ commitments: [Data]) async throws -> [Data]
    var fetchNullifierExclusionProofs: @Sendable (_ nullifiers: [Data]) async throws -> [Data]
    var fetchCommitmentTreeState: @Sendable (_ height: UInt64) async throws -> CommitmentTreeState
    var fetchLatestCommitmentTree: @Sendable () async throws -> CommitmentTreeState
    var submitDelegation: @Sendable (_ registration: DelegationRegistration) async throws -> TxResult
    var submitVoteCommitment: @Sendable (_ bundle: VoteCommitmentBundle, _ signature: CastVoteSignature) async throws -> TxResult
    /// Distribute shares across available vote servers. Config must be set via `configureURLs` first.
    /// Returns info about which servers accepted each share.
    var delegateShares: @Sendable (_ payloads: [SharePayload], _ roundIdHex: String) async throws -> [DelegatedShareInfo]
    /// Poll a helper server for the confirmation status of a share identified by its nullifier.
    var fetchShareStatus: @Sendable (_ helperBaseURL: String, _ roundIdHex: String, _ nullifierHex: String) async throws -> ShareConfirmationResult
    /// Resubmit a single share to healthy servers, excluding the given URLs.
    /// Returns the list of server URLs that accepted the share (empty if all failed).
    var resubmitShare: @Sendable (_ payload: SharePayload, _ roundIdHex: String, _ excludeURLs: [String]) async throws -> [String]
    var fetchProposalTally: @Sendable (_ roundId: Data, _ proposalId: UInt32) async throws -> TallyResult
    /// Query the Cosmos SDK TX endpoint for a confirmed transaction and its ABCI events.
    /// Returns nil if the TX is not yet in a block (404 or network error).
    var fetchTxConfirmation: @Sendable (_ txHash: String) async throws -> TxConfirmation?
}
