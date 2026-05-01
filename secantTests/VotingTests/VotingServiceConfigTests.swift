import XCTest
import ComposableArchitecture
import ZcashLightClientKit
@testable import secant_testnet

final class VotingServiceConfigTests: XCTestCase {

    // MARK: - Decode regression for chain-sourced proposals config

    func testDecodeFromFullZIP1244CompliantJSON() throws {
        let json = """
        {
          "config_version": 1,
          "vote_round_id": "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899",
          "vote_servers": [
            {"url": "https://vote1.example.com", "label": "validator-1"}
          ],
          "pir_endpoints": [
            {"url": "https://pir1.example.com", "label": "pir-1"}
          ],
          "supported_versions": {
            "pir": ["v0", "v1"],
            "vote_protocol": "v0",
            "tally": "v0",
            "vote_server": "v1"
          }
        }
        """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(VotingServiceConfig.self, from: data)

        XCTAssertEqual(config.configVersion, 1)
        XCTAssertEqual(config.voteRoundId, "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899")
        XCTAssertEqual(config.voteServers.count, 1)
        XCTAssertEqual(config.pirEndpoints.first?.label, "pir-1")
        XCTAssertEqual(config.supportedVersions.voteServer, "v1")
        XCTAssertEqual(config.supportedVersions.pir, ["v0", "v1"])
    }

    func testDecodeAcceptsConfigWithoutProposalsSnapshotOrDeadline() {
        let json = """
        {
          "config_version": 1,
          "vote_round_id": "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899",
          "vote_servers": [{"url": "https://x", "label": "a"}],
          "pir_endpoints": [{"url": "https://y", "label": "b"}],
          "supported_versions": {"pir": ["v0"], "vote_protocol": "v0", "tally": "v0", "vote_server": "v1"}
        }
        """
        XCTAssertNoThrow(try JSONDecoder().decode(VotingServiceConfig.self, from: Data(json.utf8)))
    }

    // MARK: - validate() — supported_versions enforcement

    private func makeConfig(supportedVersions: VotingServiceConfig.SupportedVersions) -> VotingServiceConfig {
        VotingServiceConfig(
            configVersion: 1,
            voteRoundId: String(repeating: "a", count: 64),
            voteServers: [.init(url: "https://x", label: "a")],
            pirEndpoints: [.init(url: "https://y", label: "b")],
            supportedVersions: supportedVersions
        )
    }

    func testValidateAcceptsCurrentWalletCapabilities() throws {
        let config = makeConfig(
            supportedVersions: .init(pir: ["v0"], voteProtocol: "v0", tally: "v0", voteServer: "v1")
        )
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateRejectsUnknownVoteServer() {
        let config = makeConfig(
            supportedVersions: .init(pir: ["v0"], voteProtocol: "v0", tally: "v0", voteServer: "v99")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            guard case VotingConfigError.unsupportedVersion(let component, let advertised) = error else {
                return XCTFail("expected unsupportedVersion, got \(error)")
            }
            XCTAssertEqual(component, "vote_server")
            XCTAssertEqual(advertised, "v99")
        }
    }

    func testValidateRejectsWhenPIRIntersectionIsEmpty() {
        let config = makeConfig(
            supportedVersions: .init(pir: ["v42"], voteProtocol: "v0", tally: "v0", voteServer: "v1")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            guard case VotingConfigError.unsupportedVersion(let component, _) = error else {
                return XCTFail("expected unsupportedVersion, got \(error)")
            }
            XCTAssertEqual(component, "pir")
        }
    }

    func testValidateAcceptsWhenPIRIntersectionIsNonEmpty() throws {
        let config = makeConfig(
            supportedVersions: .init(pir: ["v42", "v0"], voteProtocol: "v0", tally: "v0", voteServer: "v1")
        )
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateRejectsUnknownVoteProtocol() {
        let config = makeConfig(
            supportedVersions: .init(pir: ["v0"], voteProtocol: "v99", tally: "v0", voteServer: "v1")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            guard case VotingConfigError.unsupportedVersion(let component, _) = error else {
                return XCTFail("expected unsupportedVersion, got \(error)")
            }
            XCTAssertEqual(component, "vote_protocol")
        }
    }

    func testValidateRejectsUnknownTally() {
        let config = makeConfig(
            supportedVersions: .init(pir: ["v0"], voteProtocol: "v0", tally: "v99", voteServer: "v1")
        )
        XCTAssertThrowsError(try config.validate()) { error in
            guard case VotingConfigError.unsupportedVersion(let component, _) = error else {
                return XCTFail("expected unsupportedVersion, got \(error)")
            }
            XCTAssertEqual(component, "tally")
        }
    }
}

private actor SharePostRecorder {
    private var postedServers: [String] = []

    func record(_ server: String) {
        postedServers.append(server)
    }

    func servers() -> [String] {
        postedServers
    }
}

private actor VoteSubmissionRecorder {
    private var submittedProposalIds: [UInt32] = []

    func recordSubmittedProposal(_ proposalId: UInt32) {
        submittedProposalIds.append(proposalId)
    }

    func submittedProposals() -> [UInt32] {
        submittedProposalIds
    }
}

private actor ShareServerURLRecorder {
    private var serverURLBatches: [[String]] = []

    func record(_ serverURLs: [String]) {
        serverURLBatches.append(serverURLs)
    }

    func batches() -> [[String]] {
        serverURLBatches
    }
}

private actor RecoveryOrderRecorder {
    private var recordedEvents: [String] = []

    func record(_ event: String) {
        recordedEvents.append(event)
    }

    func events() -> [String] {
        recordedEvents
    }
}

private actor AttemptCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }

    func value() -> Int {
        count
    }
}

private struct SharePostFailure: Error {}

private func makeShareDelegation(
    roundId: String = "aabb",
    bundleIndex: UInt32 = 0,
    proposalId: UInt32 = 1,
    shareIndex: UInt32 = 0,
    sentToURLs: [String],
    confirmed: Bool = false,
    submitAt: UInt64,
    createdAt: UInt64,
    nullifier: [UInt8] = Array(repeating: 0x0A, count: 32)
) throws -> VotingShareDelegation {
    let object: [String: Any] = [
        "round_id": roundId,
        "bundle_index": bundleIndex,
        "proposal_id": proposalId,
        "share_index": shareIndex,
        "sent_to_urls": sentToURLs,
        "nullifier": nullifier,
        "confirmed": confirmed,
        "submit_at": submitAt,
        "created_at": createdAt
    ]
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(VotingShareDelegation.self, from: data)
}

private func makeRecoverySharePayload(index: UInt32 = 0) -> SharePayload {
    let share = EncryptedShare(
        c1: Data(repeating: UInt8(index + 1), count: 32),
        c2: Data(repeating: UInt8(index + 2), count: 32),
        shareIndex: index
    )
    return SharePayload(
        sharesHash: Data(repeating: 0x01, count: 32),
        proposalId: 1,
        voteDecision: 0,
        encShare: share,
        treePosition: 10,
        allEncShares: [share],
        shareComms: [Data(repeating: 0x03, count: 32)],
        primaryBlind: Data(repeating: 0x04, count: 32),
        submitAt: 99
    )
}

final class ShareRecoveryPollingTests: XCTestCase {
    func testPollingConfirmsFromRecordedHelperInsteadOfFirstConfiguredHelper() async throws {
        let recorder = SharePostRecorder()
        let share = try makeShareDelegation(
            sentToURLs: [
                "https://helper-3.example.com",
                "https://helper-4.example.com",
                "https://helper-5.example.com"
            ],
            submitAt: 0,
            createdAt: 100
        )

        let result = await pollShareStatusesForRecovery(
            readyShares: [share],
            roundId: "aabb",
            now: 200,
            voteEndTime: 1_000,
            fetchShareStatus: { helperURL, _, _ in
                await recorder.record(helperURL)
                return helperURL == "https://helper-3.example.com" ? .confirmed : .pending
            }
        )

        let queriedServers = await recorder.servers()
        XCTAssertEqual(queriedServers, ["https://helper-3.example.com"])
        XCTAssertEqual(result.confirmedShares, [
            ShareDelegationKey(bundleIndex: 0, proposalId: 1, shareIndex: 0)
        ])
        XCTAssertTrue(result.resubmissionShares.isEmpty)
    }

    func testPollingContinuesAfterOneRecordedHelperErrors() async throws {
        let recorder = SharePostRecorder()
        let share = try makeShareDelegation(
            sentToURLs: [
                "https://helper-3.example.com",
                "https://helper-4.example.com"
            ],
            submitAt: 0,
            createdAt: 100
        )

        let result = await pollShareStatusesForRecovery(
            readyShares: [share],
            roundId: "aabb",
            now: 200,
            voteEndTime: 1_000,
            fetchShareStatus: { helperURL, _, _ in
                await recorder.record(helperURL)
                if helperURL == "https://helper-3.example.com" {
                    throw SharePostFailure()
                }
                return .confirmed
            }
        )

        let queriedServers = await recorder.servers()
        XCTAssertEqual(queriedServers, [
            "https://helper-3.example.com",
            "https://helper-4.example.com"
        ])
        XCTAssertEqual(result.confirmedShares, [
            ShareDelegationKey(bundleIndex: 0, proposalId: 1, shareIndex: 0)
        ])
        XCTAssertTrue(result.resubmissionShares.isEmpty)
    }

    func testImmediateSharesUseCreatedAtForReadinessAndResubmission() throws {
        let share = try makeShareDelegation(
            sentToURLs: ["https://helper.example.com"],
            submitAt: 0,
            createdAt: 100
        )

        XCTAssertFalse(isShareReadyForStatusCheck(share, now: 109, checkGrace: 10))
        XCTAssertTrue(isShareReadyForStatusCheck(share, now: 110, checkGrace: 10))
        XCTAssertFalse(shouldResubmitShare(share, now: 129, voteEndTime: 200))
        XCTAssertTrue(shouldResubmitShare(share, now: 130, voteEndTime: 200))
    }

    func testDelayedSharesUseSubmitAtForReadinessAndResubmission() throws {
        let share = try makeShareDelegation(
            sentToURLs: ["https://helper.example.com"],
            submitAt: 200,
            createdAt: 100
        )

        XCTAssertFalse(isShareReadyForStatusCheck(share, now: 209, checkGrace: 10))
        XCTAssertTrue(isShareReadyForStatusCheck(share, now: 210, checkGrace: 10))
        XCTAssertFalse(shouldResubmitShare(share, now: 229, voteEndTime: 320))
        XCTAssertTrue(shouldResubmitShare(share, now: 230, voteEndTime: 320))
    }
}

final class ShareResubmissionFallbackTests: XCTestCase {
    func testResubmissionTriesUntriedHelpersFirst() async {
        let recorder = SharePostRecorder()

        let acceptedServers = await resubmitSharePayload(
            makeRecoverySharePayload(),
            roundIdHex: "aabb",
            configuredServerURLs: [
                "https://already-sent.example.com",
                "https://untried.example.com"
            ],
            sentToURLs: ["https://already-sent.example.com"],
            postShare: { server, _ in
                await recorder.record(server)
            },
            orderServers: { $0 }
        )

        XCTAssertEqual(acceptedServers, ["https://untried.example.com"])
        let postedServers = await recorder.servers()
        XCTAssertEqual(postedServers, ["https://untried.example.com"])
    }

    func testResubmissionFallsBackToAlreadySentHelperWhenUntriedFails() async {
        let recorder = SharePostRecorder()

        let acceptedServers = await resubmitSharePayload(
            makeRecoverySharePayload(),
            roundIdHex: "aabb",
            configuredServerURLs: [
                "https://already-sent.example.com",
                "https://untried.example.com"
            ],
            sentToURLs: ["https://already-sent.example.com"],
            postShare: { server, _ in
                await recorder.record(server)
                if server == "https://untried.example.com" {
                    throw SharePostFailure()
                }
            },
            orderServers: { $0 }
        )

        XCTAssertEqual(acceptedServers, ["https://already-sent.example.com"])
        let postedServers = await recorder.servers()
        XCTAssertEqual(postedServers, [
            "https://untried.example.com",
            "https://already-sent.example.com"
        ])
    }

    func testResubmissionReturnsEmptyWhenAllHelpersFail() async {
        let recorder = SharePostRecorder()

        let acceptedServers = await resubmitSharePayload(
            makeRecoverySharePayload(),
            roundIdHex: "aabb",
            configuredServerURLs: [
                "https://already-sent.example.com",
                "https://untried.example.com"
            ],
            sentToURLs: ["https://already-sent.example.com"],
            postShare: { server, _ in
                await recorder.record(server)
                throw SharePostFailure()
            },
            orderServers: { $0 }
        )

        XCTAssertTrue(acceptedServers.isEmpty)
        let postedServers = await recorder.servers()
        XCTAssertEqual(postedServers, [
            "https://untried.example.com",
            "https://already-sent.example.com"
        ])
    }
}

final class ShareDelegationPostFallbackTests: XCTestCase {
    func testSelectedHelperFailureBackfillsSameShareAndPrunesFailedHelper() async throws {
        let recorder = SharePostRecorder()
        let payload = Self.makePayload(index: 0)

        let result = try await delegateSharePayloads(
            [payload],
            roundIdHex: "aabb",
            initialServerURLs: [
                "https://online-one.example.com",
                "https://offline.example.com",
                "https://online-two.example.com"
            ],
            postShare: { server, _ in
                await recorder.record(server)
                if server == "https://offline.example.com" {
                    throw SharePostFailure()
                }
            },
            selectTargets: { servers, targetCount in Array(servers.prefix(targetCount)) }
        )

        let postedServers = await recorder.servers()
        XCTAssertEqual(postedServers.count, 3)
        XCTAssertEqual(Set(postedServers), Set([
            "https://online-one.example.com",
            "https://offline.example.com",
            "https://online-two.example.com"
        ]))
        XCTAssertEqual(result.delegatedShares.first?.acceptedByServers, [
            "https://online-one.example.com",
            "https://online-two.example.com"
        ])
        XCTAssertEqual(result.remainingServerURLs, [
            "https://online-one.example.com",
            "https://online-two.example.com"
        ])
    }

    func testOfflineHelperIsAttemptedAtMostOnceThenLaterSharesUseOnlineHelper() async throws {
        let recorder = SharePostRecorder()
        let payloads = (0..<2).map { Self.makePayload(index: UInt32($0)) }

        let result = try await delegateSharePayloads(
            payloads,
            roundIdHex: "aabb",
            initialServerURLs: [
                "https://offline.example.com",
                "https://online.example.com"
            ],
            postShare: { server, _ in
                await recorder.record(server)
                if server == "https://offline.example.com" {
                    throw SharePostFailure()
                }
            },
            selectTargets: { servers, targetCount in Array(servers.prefix(targetCount)) }
        )

        let postedServers = await recorder.servers()
        XCTAssertEqual(postedServers, [
            "https://offline.example.com",
            "https://online.example.com",
            "https://online.example.com"
        ])
        XCTAssertEqual(result.delegatedShares.map(\.acceptedByServers), [
            ["https://online.example.com"],
            ["https://online.example.com"]
        ])
        XCTAssertEqual(result.remainingServerURLs, ["https://online.example.com"])
    }

    func testAllSelectedHelpersFailButBackfillHelperSucceeds() async throws {
        let recorder = SharePostRecorder()
        let payload = Self.makePayload(index: 0)

        let result = try await delegateSharePayloads(
            [payload],
            roundIdHex: "aabb",
            initialServerURLs: [
                "https://offline-one.example.com",
                "https://offline-two.example.com",
                "https://online.example.com"
            ],
            postShare: { server, _ in
                await recorder.record(server)
                if server != "https://online.example.com" {
                    throw SharePostFailure()
                }
            },
            selectTargets: { servers, targetCount in Array(servers.prefix(targetCount)) }
        )

        let postedServers = await recorder.servers()
        XCTAssertEqual(postedServers.count, 3)
        XCTAssertEqual(Set(postedServers), Set([
            "https://offline-one.example.com",
            "https://offline-two.example.com",
            "https://online.example.com"
        ]))
        XCTAssertEqual(result.delegatedShares.first?.acceptedByServers, ["https://online.example.com"])
        XCTAssertEqual(result.remainingServerURLs, ["https://online.example.com"])
    }

    func testAllConfiguredHelpersFailThrowsNoReachableVoteServers() async throws {
        let payload = Self.makePayload(index: 0)

        do {
            _ = try await delegateSharePayloads(
                [payload],
                roundIdHex: "aabb",
                initialServerURLs: [
                    "https://offline-one.example.com",
                    "https://offline-two.example.com"
                ],
                postShare: { _, _ in throw SharePostFailure() },
                selectTargets: { servers, targetCount in Array(servers.prefix(targetCount)) }
            )
            XCTFail("Expected share delegation to fail")
        } catch {
            XCTAssertEqual(error as? ShareDelegationError, .noReachableVoteServers)
        }
    }

    private static func makePayload(index: UInt32) -> SharePayload {
        let share = EncryptedShare(
            c1: Data(repeating: UInt8(index + 1), count: 32),
            c2: Data(repeating: UInt8(index + 2), count: 32),
            shareIndex: index
        )
        return SharePayload(
            sharesHash: Data(repeating: 0x01, count: 32),
            proposalId: 1,
            voteDecision: 0,
            encShare: share,
            treePosition: 10,
            allEncShares: [share],
            shareComms: [Data(repeating: 0x03, count: 32)],
            primaryBlind: Data(repeating: 0x04, count: 32),
            submitAt: 0
        )
    }
}

@MainActor
final class VotingSubmissionPostFallbackTests: XCTestCase {
    func testRoundTappedResetsDelegationStateWhenSwitchingRounds() async {
        let round = Self.makeVotingRound()
        let newSession = Self.makeVotingSession(
            proposals: round.proposals,
            roundByte: 0xBB,
            status: .unspecified
        )
        var initialState = Self.makeReadySubmissionState(round: round)
        initialState.allRounds = [
            Voting.State.RoundListItem(roundNumber: 2, session: newSession)
        ]
        initialState.delegationProofStatus = .complete
        initialState.isDelegationProofInFlight = true
        initialState.pendingBatchSubmission = true
        initialState.currentKeystoneBundleIndex = 1
        initialState.keystoneBundleSignatures = [
            .init(sig: Data([0x01]), sighash: Data([0x02]), rk: Data([0x03]))
        ]
        initialState.keystoneSigningStatus = .preparingRequest

        let store = TestStore(initialState: initialState) {
            Voting()
        }
        store.exhaustivity = .off

        await store.send(.roundTapped(newSession.voteRoundId.hexString))

        XCTAssertEqual(store.state.roundId, newSession.voteRoundId.hexString)
        XCTAssertEqual(store.state.delegationProofStatus, .notStarted)
        XCTAssertFalse(store.state.isDelegationProofInFlight)
        XCTAssertFalse(store.state.pendingBatchSubmission)
        XCTAssertEqual(store.state.currentKeystoneBundleIndex, 0)
        XCTAssertEqual(store.state.keystoneBundleSignatures, [])
        XCTAssertEqual(store.state.keystoneSigningStatus, .idle)
    }

    func testBackToRoundsListClearsPendingKeystoneBatch() async {
        let round = Self.makeVotingRound()
        var initialState = Self.makeReadySubmissionState(round: round)
        initialState.pendingBatchSubmission = true
        initialState.currentKeystoneBundleIndex = 1
        initialState.keystoneBundleSignatures = [
            .init(sig: Data([0x01]), sighash: Data([0x02]), rk: Data([0x03]))
        ]
        initialState.keystoneSigningStatus = .awaitingSignature

        let store = TestStore(initialState: initialState) {
            Voting()
        }
        store.exhaustivity = .off
        store.dependencies.votingAPI.fetchAllRounds = { [] }

        await store.send(.backToRoundsList)

        XCTAssertFalse(store.state.pendingBatchSubmission)
        XCTAssertEqual(store.state.currentKeystoneBundleIndex, 0)
        XCTAssertEqual(store.state.keystoneBundleSignatures, [])
        XCTAssertEqual(store.state.keystoneSigningStatus, .idle)
    }

    func testStaleDelegationCompletionDoesNotMutateSelectedRound() async {
        let round = Self.makeVotingRound()
        var initialState = Self.makeReadySubmissionState(round: round)
        initialState.delegationProofStatus = .notStarted
        initialState.isDelegationProofInFlight = true

        let store = TestStore(initialState: initialState) {
            Voting()
        }
        store.exhaustivity = .off

        await store.send(.delegationProofCompleted(roundId: String(repeating: "b", count: 64)))

        XCTAssertEqual(store.state.delegationProofStatus, .notStarted)
        XCTAssertTrue(store.state.isDelegationProofInFlight)
    }

    func testDelegateSharesWithFallbackRetriesReachabilityExhaustion() async throws {
        let attempts = AttemptCounter()
        var votingAPI = VotingAPIClient()
        votingAPI.delegateShares = { _, _, serverURLs in
            let attempt = await attempts.increment()
            if attempt < 3 {
                throw ShareDelegationError.noReachableVoteServers
            }
            return ShareDelegationResult(delegatedShares: [], remainingServerURLs: serverURLs)
        }

        let result = try await Voting.delegateSharesWithFallback(
            [],
            roundId: "aabb",
            votingAPI: votingAPI,
            serverURLs: ["https://vote.example.com"],
            retryDelay: .zero
        )

        XCTAssertEqual(await attempts.value(), 3)
        XCTAssertEqual(result.remainingServerURLs, ["https://vote.example.com"])
    }

    func testDelegateSharesWithFallbackRethrowsUnexpectedErrorWithoutRetry() async {
        let attempts = AttemptCounter()
        var votingAPI = VotingAPIClient()
        votingAPI.delegateShares = { _, _, _ in
            _ = await attempts.increment()
            throw SharePostFailure()
        }

        do {
            _ = try await Voting.delegateSharesWithFallback(
                [],
                roundId: "aabb",
                votingAPI: votingAPI,
                serverURLs: ["https://vote.example.com"],
                retryDelay: .zero
            )
            XCTFail("Expected unexpected share delegation error")
        } catch {
            XCTAssertTrue(error is SharePostFailure)
        }
        XCTAssertEqual(await attempts.value(), 1)
    }

    func testFailureInFirstProposalRemovesHelperForSecondProposalInSameSubmission() async {
        let round = Self.makeVotingRound(proposalCount: 2)
        var initialState = Self.makeReadySubmissionState(round: round)
        initialState.draftVotes = [1: .option(0), 2: .option(0)]

        let submittedRecorder = VoteSubmissionRecorder()
        let serverURLRecorder = ShareServerURLRecorder()
        let store = Self.makeSubmissionStore(
            initialState: initialState,
            submittedRecorder: submittedRecorder,
            delegateShares: { payloads, _, serverURLs in
                await serverURLRecorder.record(serverURLs)
                let acceptedServer = serverURLs.contains("https://online.example.com")
                    ? "https://online.example.com"
                    : serverURLs[0]
                return ShareDelegationResult(
                    delegatedShares: payloads.map {
                        DelegatedShareInfo(
                            shareIndex: $0.encShare.shareIndex,
                            proposalId: $0.proposalId,
                            acceptedByServers: [acceptedServer]
                        )
                    },
                    remainingServerURLs: ["https://online.example.com"]
                )
            }
        )

        await store.send(.authenticationSucceeded)
        await store.finish()
        await store.skipReceivedActions()

        let submittedProposals = await submittedRecorder.submittedProposals()
        let serverURLBatches = await serverURLRecorder.batches()
        XCTAssertEqual(submittedProposals, [1, 2])
        XCTAssertEqual(serverURLBatches, [
            ["https://offline.example.com", "https://online.example.com"],
            ["https://online.example.com"]
        ])
    }

    func testShareServerExhaustionStopsBeforeSubmittingLaterDrafts() async {
        let round = Self.makeVotingRound(proposalCount: 2)
        var initialState = Self.makeReadySubmissionState(round: round)
        initialState.draftVotes = [1: .option(0), 2: .option(0)]

        let submittedRecorder = VoteSubmissionRecorder()
        let store = Self.makeSubmissionStore(
            initialState: initialState,
            submittedRecorder: submittedRecorder,
            delegateShares: { _, _, _ in
                throw ShareDelegationError.noReachableVoteServers
            }
        )

        await store.send(.authenticationSucceeded)
        await store.finish()
        await store.skipReceivedActions()

        let submittedProposals = await submittedRecorder.submittedProposals()
        XCTAssertEqual(submittedProposals, [1])
        XCTAssertEqual(store.state.draftVotes, [1: .option(0), 2: .option(0)])
        XCTAssertEqual(store.state.batchVoteErrors.keys.sorted(), [1])
        guard case let .submissionFailed(_, submittedCount, totalCount) = store.state.batchSubmissionStatus,
              submittedCount == 0,
              totalCount == 1
        else {
            return XCTFail("Expected submission failure for only the attempted proposal")
        }
    }

    func testCachedTxRecoveryStoresRecoveredVCPositionBeforeShareRetry() async {
        let round = Self.makeVotingRound()
        var initialState = Self.makeReadySubmissionState(round: round)
        initialState.draftVotes = [1: .option(0)]

        let orderRecorder = RecoveryOrderRecorder()
        let submittedRecorder = VoteSubmissionRecorder()
        let savedBundle = Self.makeVoteCommitmentBundle(
            proposalId: 1,
            roundId: initialState.roundId,
            anchorHeight: 1
        )
        let store = Self.makeSubmissionStore(
            initialState: initialState,
            submittedRecorder: submittedRecorder,
            delegateShares: { payloads, _, serverURLs in
                await orderRecorder.record("delegate:\(payloads.first?.treePosition ?? 0)")
                return ShareDelegationResult(
                    delegatedShares: payloads.map {
                        DelegatedShareInfo(
                            shareIndex: $0.encShare.shareIndex,
                            proposalId: $0.proposalId,
                            acceptedByServers: [serverURLs[0]]
                        )
                    },
                    remainingServerURLs: serverURLs
                )
            },
            getVoteTxHash: { _, _, _ in .present("cached-tx") },
            fetchTxConfirmation: { _ in
                TxConfirmation(
                    height: 1,
                    code: 0,
                    events: [
                        TxEvent(
                            type: "cast_vote",
                            attributes: [.init(key: "leaf_index", value: "0,7")]
                        )
                    ]
                )
            },
            getVoteCommitmentBundle: { _, _, _ in savedBundle },
            storeVoteCommitmentBundle: { _, _, _, _, vcTreePosition in
                await orderRecorder.record("store:\(vcTreePosition)")
            }
        )

        await store.send(.authenticationSucceeded)
        await store.finish()
        await store.skipReceivedActions()

        let events = await orderRecorder.events()
        XCTAssertEqual(events, ["store:7", "delegate:7"])
    }

    private static func makeSubmissionStore(
        initialState: Voting.State,
        submittedRecorder: VoteSubmissionRecorder,
        delegateShares: @escaping @Sendable ([SharePayload], String, [String]) async throws -> ShareDelegationResult,
        getVoteTxHash: @escaping @Sendable (String, UInt32, UInt32) async throws -> VotingTxHashLookup = { _, _, _ in
            throw SharePostFailure()
        },
        fetchTxConfirmation: @escaping @Sendable (String) async throws -> TxConfirmation? = { _ in
            TxConfirmation(
                height: 1,
                code: 0,
                events: [
                    TxEvent(
                        type: "cast_vote",
                        attributes: [.init(key: "leaf_index", value: "0,0")]
                    )
                ]
            )
        },
        getVoteCommitmentBundle: @escaping @Sendable (String, UInt32, UInt32) async throws -> VoteCommitmentBundle? = { _, _, _ in
            nil
        },
        storeVoteCommitmentBundle: @escaping @Sendable (
            String,
            UInt32,
            UInt32,
            VoteCommitmentBundle,
            UInt64
        ) async throws -> Void = { _, _, _, _, _ in }
    ) -> TestStore<Voting.State, Voting.Action> {
        let store = TestStore(initialState: initialState) {
            Voting()
        }
        store.exhaustivity = .off
        store.dependencies.backgroundTask = .noOp
        store.dependencies.mnemonic = .noOp
        store.dependencies.walletStorage = .noOp

        var votingAPI = VotingAPIClient()
        votingAPI.submitVoteCommitment = { bundle, _ in
            await submittedRecorder.recordSubmittedProposal(bundle.proposalId)
            return TxResult(txHash: "tx-\(bundle.proposalId)", code: 0)
        }
        votingAPI.fetchTxConfirmation = fetchTxConfirmation
        votingAPI.delegateShares = delegateShares
        store.dependencies.votingAPI = votingAPI

        var votingCrypto = VotingCryptoClient()
        votingCrypto.getVotes = { _ in [] }
        votingCrypto.getVoteTxHash = getVoteTxHash
        votingCrypto.syncVoteTree = { _, _ in 1 }
        votingCrypto.generateVanWitness = { _, _, anchorHeight in
            VanWitness(authPath: [], position: 0, anchorHeight: anchorHeight)
        }
        votingCrypto.buildVoteCommitment = {
            roundId, _, _, _, proposalId, _, _, _, _, anchorHeight, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.completed(
                    Self.makeVoteCommitmentBundle(
                        proposalId: proposalId,
                        roundId: roundId,
                        anchorHeight: anchorHeight
                    )
                ))
                continuation.finish()
            }
        }
        votingCrypto.storeVoteCommitmentBundle = storeVoteCommitmentBundle
        votingCrypto.getVoteCommitmentBundle = getVoteCommitmentBundle
        votingCrypto.signCastVote = { _, _, _ in CastVoteSignature(voteAuthSig: Data([0x01])) }
        votingCrypto.storeVoteTxHash = { _, _, _, _ in }
        votingCrypto.storeVanPosition = { _, _, _ in }
        votingCrypto.buildSharePayloads = { _, bundle, choice, _, treePosition, _ in
            [Self.makeSharePayload(
                proposalId: bundle.proposalId,
                voteDecision: choice.index,
                treePosition: treePosition
            )]
        }
        votingCrypto.computeShareNullifier = { _, _, _ in String(repeating: "00", count: 32) }
        votingCrypto.recordShareDelegation = { _, _, _, _, _, _, _ in }
        votingCrypto.markVoteSubmitted = { _, _, _ in }
        store.dependencies.votingCrypto = votingCrypto

        return store
    }

    private static func makeReadySubmissionState(round: VotingRound) -> Voting.State {
        var state = Voting.State(
            votingRound: round,
            votingWeight: 100_000_000,
            isKeystoneUser: false,
            walletId: "wallet-\(UUID().uuidString)",
            roundId: "aabb"
        )
        state.activeSession = Self.makeVotingSession(proposals: round.proposals)
        state.serviceConfig = Self.makeServiceConfig()
        state.bundleCount = 1
        state.delegationProofStatus = .complete
        return state
    }

    private static func makeVotingRound(proposalCount: Int = 1) -> VotingRound {
        VotingRound(
            id: "aabb",
            title: "Round",
            description: "Round description",
            snapshotHeight: 1,
            snapshotDate: Date(timeIntervalSince1970: 1),
            votingStart: Date(timeIntervalSince1970: 2),
            votingEnd: Date(timeIntervalSince1970: 3),
            proposals: (1...proposalCount).map { id in
                VotingProposal(
                    id: UInt32(id),
                    title: "Proposal \(id)",
                    description: "Proposal description",
                    options: [
                        .init(index: 0, label: "Yes"),
                        .init(index: 1, label: "No")
                    ]
                )
            }
        )
    }

    nonisolated private static func makeVoteCommitmentBundle(
        proposalId: UInt32,
        roundId: String,
        anchorHeight: UInt32
    ) -> VoteCommitmentBundle {
        let share = EncryptedShare(
            c1: Data(repeating: 0x01, count: 32),
            c2: Data(repeating: 0x02, count: 32),
            shareIndex: 0
        )
        return VoteCommitmentBundle(
            vanNullifier: Data(repeating: 0x03, count: 32),
            voteAuthorityNoteNew: Data(repeating: 0x04, count: 32),
            voteCommitment: Data(repeating: 0x05, count: 32),
            proposalId: proposalId,
            proof: Data(repeating: 0x06, count: 32),
            encShares: [share],
            anchorHeight: anchorHeight,
            voteRoundId: roundId,
            sharesHash: Data(repeating: 0x07, count: 32),
            shareBlindFactors: [Data(repeating: 0x08, count: 32)],
            shareComms: [Data(repeating: 0x09, count: 32)],
            rVpkBytes: Data(repeating: 0x0A, count: 32),
            alphaV: Data(repeating: 0x0B, count: 32)
        )
    }

    nonisolated private static func makeSharePayload(
        proposalId: UInt32,
        voteDecision: UInt32,
        treePosition: UInt64
    ) -> SharePayload {
        let share = EncryptedShare(
            c1: Data(repeating: 0x01, count: 32),
            c2: Data(repeating: 0x02, count: 32),
            shareIndex: 0
        )
        return SharePayload(
            sharesHash: Data(repeating: 0x03, count: 32),
            proposalId: proposalId,
            voteDecision: voteDecision,
            encShare: share,
            treePosition: treePosition,
            allEncShares: [share],
            shareComms: [Data(repeating: 0x04, count: 32)],
            primaryBlind: Data(repeating: 0x05, count: 32),
            submitAt: 0
        )
    }

    private static func makeVotingSession(
        proposals: [VotingProposal],
        roundByte: UInt8 = 0xAA,
        status: SessionStatus = .active
    ) -> VotingSession {
        VotingSession(
            voteRoundId: Data(repeating: roundByte, count: 32),
            snapshotHeight: 1,
            snapshotBlockhash: Data(repeating: 0x01, count: 32),
            proposalsHash: Data(repeating: 0x02, count: 32),
            voteEndTime: Date(timeIntervalSince1970: 3),
            ceremonyStart: Date(timeIntervalSince1970: 2),
            eaPK: Data(repeating: 0x03, count: 32),
            vkZkp1: Data(repeating: 0x04, count: 32),
            vkZkp2: Data(repeating: 0x05, count: 32),
            vkZkp3: Data(repeating: 0x06, count: 32),
            ncRoot: Data(repeating: 0x07, count: 32),
            nullifierIMTRoot: Data(repeating: 0x08, count: 32),
            creator: "creator",
            proposals: proposals,
            status: status
        )
    }

    private static func makeServiceConfig() -> VotingServiceConfig {
        VotingServiceConfig(
            configVersion: 1,
            voteRoundId: String(repeating: "a", count: 64),
            voteServers: [
                .init(url: "https://offline.example.com", label: "offline"),
                .init(url: "https://online.example.com", label: "online")
            ],
            pirEndpoints: [.init(url: "https://pir.example.com", label: "pir")],
            snapshotHeight: 1,
            voteEndTime: 3,
            supportedVersions: .init(pir: ["v0"], voteProtocol: "v0", tally: "v0", voteServer: "v1")
        )
    }
}
