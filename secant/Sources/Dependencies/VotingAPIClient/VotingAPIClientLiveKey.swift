import ComposableArchitecture
import Foundation
import os

private let logger = Logger(subsystem: "co.zodl.voting", category: "VotingAPIClient")

// MARK: - API Configuration

/// Mutable runtime configuration for the Shielded-Vote chain REST API and helper server.
/// URLs are resolved from the CDN service config at startup.
actor SvAPIConfigStore {
    static let shared = SvAPIConfigStore()

    /// Primary vote server URL (serves both chain API and helper endpoints).
    var baseURL = "https://vote-chain-primary.valargroup.org"
    /// All vote server URLs from CDN config (used for share distribution).
    var voteServerURLs: [String] = ["https://vote-chain-primary.valargroup.org"]
    /// Primary PIR server URL.
    var pirServerURL = "https://pir.valargroup.org"

    func configure(from config: VotingServiceConfig) {
        if let first = config.voteServers.first {
            baseURL = first.url
        }
        voteServerURLs = config.voteServers.map(\.url)
        if let first = config.pirEndpoints.first {
            pirServerURL = first.url
        }
    }
}

// MARK: - Errors

private enum SvAPIError: LocalizedError {
    case httpError(statusCode: Int, message: String)
    case invalidResponse(String)
    case txFailed(code: UInt32, log: String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .invalidResponse(let detail):
            return "Invalid API response: \(detail)"
        case .txFailed(let code, let log):
            return "Transaction failed (code \(code)): \(log)"
        }
    }
}

enum SvAPIResponseParser {
    static func parseJSONObject(
        _ data: Data,
        response: HTTPURLResponse,
        context: String
    ) throws -> [String: Any] {
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try unwrapJSONObject(object, data: data, response: response, context: context)
        } catch {
            throw SvAPIError.invalidResponse(
                "\(context): JSON parse failed (\(responseMetadata(response))) — \(bodySnippet(data))"
            )
        }
    }

    static func parseTxResult(_ json: [String: Any]) throws -> TxResult {
        for candidate in txResultCandidates(from: json) {
            let hasResultFields =
                candidate["tx_hash"] != nil ||
                candidate["txhash"] != nil ||
                candidate["hash"] != nil ||
                candidate["code"] != nil ||
                candidate["log"] != nil ||
                candidate["raw_log"] != nil ||
                candidate["error"] != nil
            guard hasResultFields else { continue }

            let txHash =
                (candidate["tx_hash"] as? String) ??
                (candidate["txhash"] as? String) ??
                (candidate["hash"] as? String) ??
                ""
            let code = parseUInt32(candidate["code"])
            let log =
                (candidate["log"] as? String) ??
                (candidate["raw_log"] as? String) ??
                (candidate["error"] as? String) ??
                ""

            if code != 0 {
                throw SvAPIError.txFailed(code: code, log: log)
            }
            return TxResult(txHash: txHash, code: code, log: log)
        }

        if let error = json["error"] as? String, !error.isEmpty {
            throw SvAPIError.invalidResponse("tx submission returned error: \(error)")
        }
        throw SvAPIError.invalidResponse("missing tx result fields")
    }

    private static func unwrapJSONObject(
        _ object: Any,
        data: Data,
        response: HTTPURLResponse,
        context: String
    ) throws -> [String: Any] {
        if let json = object as? [String: Any] {
            return json
        }

        // Some upstreams double-encode JSON objects as a top-level JSON string.
        if let string = object as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let nestedData = trimmed.data(using: .utf8),
               let nested = try? JSONSerialization.jsonObject(with: nestedData) as? [String: Any] {
                logger.error("[VotingAPI] \(context) returned double-encoded JSON")
                return nested
            }
        }

        throw SvAPIError.invalidResponse(
            "\(context): expected JSON object, got \(describeJSONValue(object)) (\(responseMetadata(response))) — \(bodySnippet(data))"
        )
    }

    private static func txResultCandidates(from json: [String: Any]) -> [[String: Any]] {
        [
            json,
            json["tx_response"] as? [String: Any],
            json["result"] as? [String: Any]
        ].compactMap { $0 }
    }

    private static func describeJSONValue(_ value: Any) -> String {
        switch value {
        case is [Any]:
            return "array"
        case is String:
            return "string"
        case is NSNumber:
            return "number"
        case is NSNull:
            return "null"
        default:
            return String(describing: type(of: value))
        }
    }

    private static func responseMetadata(_ response: HTTPURLResponse) -> String {
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "unknown content type"
        return "HTTP \(response.statusCode), Content-Type: \(contentType)"
    }

    private static func bodySnippet(_ data: Data, limit: Int = 512) -> String {
        guard !data.isEmpty else { return "<empty body>" }
        let snippet = String(data: data.prefix(limit), encoding: .utf8) ?? "<non-utf8>"
        return snippet.replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - HTTP Helpers

/// URLSession configured with a long timeout to accommodate ZKP verification (30-60s).
private let httpSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120
    return URLSession(configuration: config)
}()

/// Fast URLSession for share POSTs and health probes (5s timeout).
/// Share delivery should fail fast so we can failover to another server.
private let fastHttpSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 10
    config.httpMaximumConnectionsPerHost = 2
    return URLSession(configuration: config)
}()

private func getJSON(_ path: String, baseURL: String? = nil) async throws -> [String: Any] {
    let resolvedDefault = await SvAPIConfigStore.shared.baseURL
    let base = baseURL ?? resolvedDefault
    guard let url = URL(string: "\(base)\(path)") else {
        throw SvAPIError.invalidResponse("invalid URL: \(base)\(path)")
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await httpSession.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw SvAPIError.invalidResponse("not an HTTP response")
    }
    guard http.statusCode == 200 else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw SvAPIError.httpError(statusCode: http.statusCode, message: body)
    }
    return try SvAPIResponseParser.parseJSONObject(data, response: http, context: "GET \(path)")
}

private func postJSON(_ path: String, body: [String: Any], baseURL: String? = nil) async throws -> [String: Any] {
    let resolvedDefault = await SvAPIConfigStore.shared.baseURL
    let base = baseURL ?? resolvedDefault
    guard let url = URL(string: "\(base)\(path)") else {
        throw SvAPIError.invalidResponse("invalid URL: \(base)\(path)")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await httpSession.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw SvAPIError.invalidResponse("not an HTTP response")
    }
    guard http.statusCode == 200 else {
        // 422 = chain processed the request but rejected the TX (non-zero CheckTx code).
        // Parse the structured body for code/log instead of returning a raw HTTP error.
        if http.statusCode == 422,
           let json = try? SvAPIResponseParser.parseJSONObject(data, response: http, context: "POST \(path)") {
            let code = (json["code"] as? NSNumber)?.uint32Value ?? 0
            let log = json["log"] as? String ?? ""
            if code != 0 {
                throw SvAPIError.txFailed(code: code, log: log)
            }
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        throw SvAPIError.httpError(statusCode: http.statusCode, message: body)
    }
    return try SvAPIResponseParser.parseJSONObject(data, response: http, context: "POST \(path)")
}

/// POST JSON to a specific vote server URL. Returns parsed JSON response.
private func postServerJSON(_ serverURL: String, _ path: String, body: [String: Any]) async throws -> [String: Any] {
    guard let url = URL(string: "\(serverURL)\(path)") else {
        throw SvAPIError.invalidResponse("invalid URL: \(serverURL)\(path)")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await fastHttpSession.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw SvAPIError.invalidResponse("not an HTTP response")
    }
    guard http.statusCode == 200 else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw SvAPIError.httpError(statusCode: http.statusCode, message: body)
    }
    return try SvAPIResponseParser.parseJSONObject(data, response: http, context: "POST \(path)")
}

/// Parse a broadcast TX response into TxResult. Throws on non-zero code.
private func parseTxResult(_ json: [String: Any]) throws -> TxResult {
    try SvAPIResponseParser.parseTxResult(json)
}

// MARK: - Broadcast Retry

/// Whether a broadcast error is transient and worth retrying.
/// Network failures and 502/503 (CometBFT gateway errors) are retryable.
/// Deterministic failures like 422 (CheckTx rejection) and 400 (bad request) are not.
private func isBroadcastRetryable(_ error: Error) -> Bool {
    if error is URLError { return true }
    if case SvAPIError.httpError(let status, _) = error {
        return status == 502 || status == 503
    }
    return false
}

/// Retry an async operation with exponential backoff.
/// Only retries when `isRetryable` returns true for the thrown error.
private func retryWithBackoff<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 2,
    factor: Double = 2,
    isRetryable: (Error) -> Bool,
    operation: () async throws -> T
) async throws -> T {
    var delay = initialDelay
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            let isLast = attempt == maxAttempts
            if isLast || !isRetryable(error) { throw error }
            print("[shielded-vote-api] broadcast attempt \(attempt)/\(maxAttempts) failed (\(error.localizedDescription)), retrying in \(delay)s")
            try await Task.sleep(for: .seconds(delay))
            delay *= factor
        }
    }
    fatalError("unreachable")
}

// MARK: - Protobuf JSON Parsing Helpers

/// Parse a uint64 value that may come as a string (protobuf JSON) or number.
private func parseUInt64(_ value: Any?) -> UInt64 {
    if let str = value as? String, let n = UInt64(str) { return n }
    if let num = value as? NSNumber { return num.uint64Value }
    return 0
}

/// Parse a uint32 value from JSON (number or string).
private func parseUInt32(_ value: Any?) -> UInt32 {
    if let str = value as? String, let n = UInt32(str) { return n }
    if let num = value as? NSNumber { return num.uint32Value }
    return 0
}

/// Decode base64-encoded bytes, returning empty Data on failure.
private func parseBase64(_ value: Any?) -> Data {
    guard let str = value as? String, let data = Data(base64Encoded: str) else { return Data() }
    return data
}

/// Convert hex string to Data.
private func dataFromHex(_ hex: String) -> Data {
    var data = Data()
    var idx = hex.startIndex
    while idx < hex.endIndex {
        let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        if let byte = UInt8(hex[idx..<next], radix: 16) {
            data.append(byte)
        }
        idx = next
    }
    return data
}

// MARK: - Response Parsers

/// Parse a VotingSession from the "round" JSON object returned by GET /shielded-vote/v1/round/{id}.
private func parseVotingSession(from round: [String: Any]) throws -> VotingSession {
    let voteEndTimeUnix = parseUInt64(round["vote_end_time"])
    let voteEndTime = Date(timeIntervalSince1970: TimeInterval(voteEndTimeUnix))
    let ceremonyStartUnix = parseUInt64(round["ceremony_phase_start"])
    let ceremonyStart = Date(timeIntervalSince1970: TimeInterval(ceremonyStartUnix))
    let statusRaw = parseUInt32(round["status"])

    // Parse proposals array with options
    var proposals: [VotingProposal] = []
    if let proposalsJSON = round["proposals"] as? [[String: Any]] {
        proposals = proposalsJSON.map { p in
            var options: [VoteOption] = []
            if let optionsJSON = p["options"] as? [[String: Any]] {
                options = optionsJSON.map { o in
                    VoteOption(
                        index: parseUInt32(o["index"]),
                        label: o["label"] as? String ?? "Option \(parseUInt32(o["index"]))"
                    )
                }
            }
            let forumURLString = p["forum_url"] as? String
            return VotingProposal(
                id: parseUInt32(p["id"]),
                title: p["title"] as? String ?? "",
                description: p["description"] as? String ?? "",
                options: options,
                zipNumber: (p["zip_number"] ?? p["zipNumber"] ?? p["zip"]) as? String,
                forumURL: forumURLString.flatMap { URL(string: $0) }
            )
        }
    }

    let discussionURLString = round["discussion_url"] as? String
    return VotingSession(
        voteRoundId: parseBase64(round["vote_round_id"]),
        snapshotHeight: parseUInt64(round["snapshot_height"]),
        snapshotBlockhash: parseBase64(round["snapshot_blockhash"]),
        proposalsHash: parseBase64(round["proposals_hash"]),
        voteEndTime: voteEndTime,
        ceremonyStart: ceremonyStart,
        eaPK: parseBase64(round["ea_pk"]),
        vkZkp1: parseBase64(round["vk_zkp1"]),
        vkZkp2: parseBase64(round["vk_zkp2"]),
        vkZkp3: parseBase64(round["vk_zkp3"]),
        ncRoot: parseBase64(round["nc_root"]),
        nullifierIMTRoot: parseBase64(round["nullifier_imt_root"]),
        creator: round["creator"] as? String ?? "",
        description: round["description"] as? String ?? "",
        discussionURL: discussionURLString.flatMap { URL(string: $0) },
        proposals: proposals,
        status: SessionStatus(rawValue: statusRaw) ?? .unspecified,
        createdAtHeight: parseUInt64(round["created_at_height"]),
        title: round["title"] as? String ?? ""
    )
}

// MARK: - Live Implementation

extension VotingAPIClient: DependencyKey {
    static var liveValue: Self {
        Self(
            fetchServiceConfig: {
                // 1. Check for local override in app bundle (debug builds only).
                //    A malformed override is a developer error — propagate the decode error.
                #if DEBUG
                if let localURL = Bundle.main.url(
                    forResource: "voting-config-local",
                    withExtension: "json"
                ) {
                    let data: Data
                    do {
                        data = try Data(contentsOf: localURL)
                    } catch {
                        throw VotingConfigError.decodeFailed("local override unreadable: \(error.localizedDescription)")
                    }
                    let config: VotingServiceConfig
                    do {
                        config = try JSONDecoder().decode(VotingServiceConfig.self, from: data)
                    } catch {
                        throw VotingConfigError.decodeFailed("local override: \(error.localizedDescription)")
                    }
                    try config.validate()
                    print("[VotingAPI] Using local override config: \(config.voteServers.count) vote servers")
                    return config
                }
                #endif

                // 2. Fetch and decode the CDN config. Any failure (transport, HTTP, decode,
                //    or version-validation) surfaces as a VotingConfigError — no silent fallback.
                let configURL = VotingServiceConfig.configURL
                let data: Data
                let response: URLResponse
                do {
                    (data, response) = try await httpSession.data(from: configURL)
                } catch {
                    throw VotingConfigError.decodeFailed("CDN fetch failed: \(error.localizedDescription)")
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw VotingConfigError.decodeFailed("CDN returned HTTP \(http.statusCode)")
                }
                let config: VotingServiceConfig
                do {
                    config = try JSONDecoder().decode(VotingServiceConfig.self, from: data)
                } catch {
                    throw VotingConfigError.decodeFailed("CDN decode failed: \(error.localizedDescription)")
                }
                try config.validate()
                print("[VotingAPI] Loaded config from CDN: \(config.voteServers.count) vote servers")
                return config
            },
            configureURLs: { config in
                await SvAPIConfigStore.shared.configure(from: config)
                await ServerHealthTracker.shared.initialize(
                    serverURLs: config.voteServers.map(\.url)
                )
                let base = await SvAPIConfigStore.shared.baseURL
                let pir = await SvAPIConfigStore.shared.pirServerURL
                print("[VotingAPI] URLs configured: base=\(base), servers=\(config.voteServers.count), pir=\(pir)")
            },
            fetchActiveVotingSession: {
                let json = try await getJSON("/shielded-vote/v1/rounds/active")
                guard let round = json["round"] as? [String: Any] else {
                    throw SvAPIError.invalidResponse("missing 'round' in response")
                }
                return try parseVotingSession(from: round)
            },
            fetchAllRounds: {
                let json = try await getJSON("/shielded-vote/v1/rounds")
                guard let roundsArray = json["rounds"] as? [[String: Any]] else {
                    // No rounds — return empty
                    return []
                }
                return try roundsArray.map { try parseVotingSession(from: $0) }
            },
            fetchRoundById: { roundIdHex in
                let json = try await getJSON("/shielded-vote/v1/round/\(roundIdHex)")
                guard let round = json["round"] as? [String: Any] else {
                    throw SvAPIError.invalidResponse("missing 'round' in response")
                }
                return try parseVotingSession(from: round)
            },
            fetchTallyResults: { roundIdHex in
                let json = try await getJSON("/shielded-vote/v1/tally-results/\(roundIdHex)")
                guard let results = json["results"] as? [[String: Any]] else {
                    return [:]
                }
                // Group by proposal_id
                var grouped: [UInt32: [TallyResult.Entry]] = [:]
                for entry in results {
                    let proposalId = parseUInt32(entry["proposal_id"])
                    let tallyEntry = TallyResult.Entry(
                        decision: parseUInt32(entry["vote_decision"]),
                        amount: parseUInt64(entry["total_value"])
                    )
                    grouped[proposalId, default: []].append(tallyEntry)
                }
                return grouped.mapValues { TallyResult(entries: $0) }
            },
            submitDelegation: { registration in
                let body: [String: Any] = [
                    "rk": registration.rk.base64EncodedString(),
                    "spend_auth_sig": registration.spendAuthSig.base64EncodedString(),
                    "sighash": registration.sighash.base64EncodedString(),
                    "signed_note_nullifier": registration.signedNoteNullifier.base64EncodedString(),
                    "cmx_new": registration.cmxNew.base64EncodedString(),
                    "van_cmx": registration.vanCmx.base64EncodedString(),
                    "gov_nullifiers": registration.govNullifiers.map { $0.base64EncodedString() },
                    "proof": registration.proof.base64EncodedString(),
                    "vote_round_id": registration.voteRoundId.base64EncodedString()
                ]
                return try await retryWithBackoff(isRetryable: isBroadcastRetryable) {
                    let json = try await postJSON("/shielded-vote/v1/delegate-vote", body: body)
                    return try parseTxResult(json)
                }
            },
            submitVoteCommitment: { bundle, signature in
                // voteRoundId is a hex string; chain expects base64-encoded bytes
                let roundIdBytes = dataFromHex(bundle.voteRoundId)
                let body: [String: Any] = [
                    "van_nullifier": bundle.vanNullifier.base64EncodedString(),
                    "vote_authority_note_new": bundle.voteAuthorityNoteNew.base64EncodedString(),
                    "vote_commitment": bundle.voteCommitment.base64EncodedString(),
                    "proposal_id": bundle.proposalId,
                    "proof": bundle.proof.base64EncodedString(),
                    "vote_round_id": roundIdBytes.base64EncodedString(),
                    "vote_comm_tree_anchor_height": bundle.anchorHeight,
                    "r_vpk": bundle.rVpkBytes.base64EncodedString(),
                    "vote_auth_sig": signature.voteAuthSig.base64EncodedString()
                ]
                return try await retryWithBackoff(isRetryable: isBroadcastRetryable) {
                    let json = try await postJSON("/shielded-vote/v1/cast-vote", body: body)
                    return try parseTxResult(json)
                }
            },
            delegateShares: { payloads, roundIdHex in
                // Send each share to ceil(s/2) healthy helpers, balancing
                // censorship resistance (redundancy) against amount privacy
                // (limiting servers that see each share's ciphertext).
                // The chain deduplicates via share nullifiers — only the first
                // MsgRevealShare per nullifier is accepted.
                let tracker = ServerHealthTracker.shared
                let healthy = await tracker.healthyServers()
                let quorum = max(1, (healthy.count + 1) / 2)

                var lastError: Error?
                var results: [DelegatedShareInfo] = []
                for (i, payload) in payloads.enumerated() {
                    let body: [String: Any] = [
                        "shares_hash": payload.sharesHash.base64EncodedString(),
                        "proposal_id": payload.proposalId,
                        "vote_decision": payload.voteDecision,
                        "enc_share": [
                            "c1": payload.encShare.c1.base64EncodedString(),
                            "c2": payload.encShare.c2.base64EncodedString(),
                            "share_index": payload.encShare.shareIndex
                        ],
                        "share_index": payload.encShare.shareIndex,
                        "tree_position": payload.treePosition,
                        "vote_round_id": roundIdHex,
                        "all_enc_shares": payload.allEncShares.map { share -> [String: Any] in
                            [
                                "c1": share.c1.base64EncodedString(),
                                "c2": share.c2.base64EncodedString(),
                                "share_index": share.shareIndex
                            ]
                        },
                        "share_comms": payload.shareComms.map { $0.base64EncodedString() },
                        "primary_blind": payload.primaryBlind.base64EncodedString(),
                        "submit_at": payload.submitAt
                    ]

                    // Pick `quorum` distinct servers uniformly at random for each
                    // share independently, so no single server sees a correlated
                    // subset of the voter's shares.
                    let targets = Array(healthy.shuffled().prefix(quorum))

                    // Send to all targets concurrently; the share is "delegated" if
                    // at least one server accepted it.
                    var accepted = false
                    var acceptedServers: [String] = []
                    var shareError: Error?
                    await withTaskGroup(of: (String, Bool).self) { group in
                        for server in targets {
                            group.addTask {
                                do {
                                    _ = try await postServerJSON(server, "/shielded-vote/v1/shares", body: body)
                                    await tracker.recordSuccess(for: server)
                                    return (server, true)
                                } catch {
                                    await tracker.recordFailure(for: server)
                                    return (server, false)
                                }
                            }
                        }
                        for await (server, ok) in group {
                            if ok {
                                accepted = true
                                acceptedServers.append(server)
                            } else {
                                print("[VotingAPI] Share \(i) failed on \(server)")
                            }
                        }
                    }

                    if !accepted {
                        // All quorum servers failed — try remaining healthy servers as fallback.
                        let targetSet = Set(targets)
                        let fallbacks = await tracker.healthyServers().filter { !targetSet.contains($0) }.shuffled()
                        for fallback in fallbacks {
                            do {
                                _ = try await postServerJSON(fallback, "/shielded-vote/v1/shares", body: body)
                                await tracker.recordSuccess(for: fallback)
                                accepted = true
                                acceptedServers.append(fallback)
                                print("[VotingAPI] Share \(i) succeeded on fallback \(fallback)")
                                break
                            } catch {
                                await tracker.recordFailure(for: fallback)
                                shareError = error
                            }
                        }
                    }

                    if accepted {
                        results.append(DelegatedShareInfo(
                            shareIndex: payload.encShare.shareIndex,
                            proposalId: payload.proposalId,
                            acceptedByServers: acceptedServers
                        ))
                    } else {
                        print("[VotingAPI] Share \(i) failed on all servers")
                        lastError = shareError ?? SvAPIError.invalidResponse("all servers rejected share \(i)")
                    }
                }

                if let lastError {
                    throw lastError
                }
                return results
            },
            fetchShareStatus: { helperBaseURL, roundIdHex, nullifierHex in
                let path = "/shielded-vote/v1/share-status/\(roundIdHex)/\(nullifierHex)"
                guard let url = URL(string: "\(helperBaseURL)\(path)") else {
                    throw SvAPIError.invalidResponse("invalid URL: \(helperBaseURL)\(path)")
                }
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                // Use the same X-Helper-Token header as share submission
                request.setValue("voting-helper", forHTTPHeaderField: "X-Helper-Token")

                let (data, response) = try await fastHttpSession.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw SvAPIError.invalidResponse("not an HTTP response")
                }
                guard http.statusCode == 200 else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw SvAPIError.httpError(statusCode: http.statusCode, message: body)
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? String
                else {
                    throw SvAPIError.invalidResponse("expected JSON with 'status' field")
                }
                switch status {
                case "confirmed":
                    return .confirmed
                default:
                    return .pending
                }
            },
            resubmitShare: { payload, roundIdHex, excludeURLs in
                let tracker = ServerHealthTracker.shared
                let excludeSet = Set(excludeURLs)
                let candidates = await tracker.healthyServers().filter { !excludeSet.contains($0) }
                guard !candidates.isEmpty else {
                    // No new servers available — try all servers as a last resort
                    // (original servers may have recovered)
                    let allHealthy = await tracker.healthyServers()
                    guard !allHealthy.isEmpty else { return [] }
                    // Fall through to attempt with all healthy
                    var accepted: [String] = []
                    for server in allHealthy.shuffled() {
                        let body: [String: Any] = [
                            "shares_hash": payload.sharesHash.base64EncodedString(),
                            "proposal_id": payload.proposalId,
                            "vote_decision": payload.voteDecision,
                            "enc_share": [
                                "c1": payload.encShare.c1.base64EncodedString(),
                                "c2": payload.encShare.c2.base64EncodedString(),
                                "share_index": payload.encShare.shareIndex
                            ],
                            "share_index": payload.encShare.shareIndex,
                            "tree_position": payload.treePosition,
                            "vote_round_id": roundIdHex,
                            "all_enc_shares": payload.allEncShares.map { share -> [String: Any] in
                                [
                                    "c1": share.c1.base64EncodedString(),
                                    "c2": share.c2.base64EncodedString(),
                                    "share_index": share.shareIndex
                                ]
                            },
                            "share_comms": payload.shareComms.map { $0.base64EncodedString() },
                            "primary_blind": payload.primaryBlind.base64EncodedString(),
                            "submit_at": 0  // immediate for resubmission
                        ]
                        do {
                            _ = try await postServerJSON(server, "/shielded-vote/v1/shares", body: body)
                            await tracker.recordSuccess(for: server)
                            accepted.append(server)
                            break  // one acceptance is enough
                        } catch {
                            await tracker.recordFailure(for: server)
                        }
                    }
                    return accepted
                }

                // Send to a subset of new servers
                let quorum = max(1, (candidates.count + 1) / 2)
                let targets = Array(candidates.shuffled().prefix(quorum))

                let body: [String: Any] = [
                    "shares_hash": payload.sharesHash.base64EncodedString(),
                    "proposal_id": payload.proposalId,
                    "vote_decision": payload.voteDecision,
                    "enc_share": [
                        "c1": payload.encShare.c1.base64EncodedString(),
                        "c2": payload.encShare.c2.base64EncodedString(),
                        "share_index": payload.encShare.shareIndex
                    ],
                    "share_index": payload.encShare.shareIndex,
                    "tree_position": payload.treePosition,
                    "vote_round_id": roundIdHex,
                    "all_enc_shares": payload.allEncShares.map { share -> [String: Any] in
                        [
                            "c1": share.c1.base64EncodedString(),
                            "c2": share.c2.base64EncodedString(),
                            "share_index": share.shareIndex
                        ]
                    },
                    "share_comms": payload.shareComms.map { $0.base64EncodedString() },
                    "primary_blind": payload.primaryBlind.base64EncodedString(),
                    "submit_at": 0  // immediate for resubmission
                ]

                var accepted: [String] = []
                await withTaskGroup(of: (String, Bool).self) { group in
                    for server in targets {
                        group.addTask {
                            do {
                                _ = try await postServerJSON(server, "/shielded-vote/v1/shares", body: body)
                                await tracker.recordSuccess(for: server)
                                return (server, true)
                            } catch {
                                await tracker.recordFailure(for: server)
                                return (server, false)
                            }
                        }
                    }
                    for await (server, ok) in group {
                        if ok { accepted.append(server) }
                    }
                }
                return accepted
            },
            fetchProposalTally: { roundId, proposalId in
                let roundIdHex = roundId.map { String(format: "%02x", $0) }.joined()
                let json = try await getJSON("/shielded-vote/v1/tally-results/\(roundIdHex)")
                guard let results = json["results"] as? [[String: Any]] else {
                    // No results yet — return empty tally
                    return TallyResult(entries: [])
                }
                let entries = results
                    .filter { parseUInt32($0["proposal_id"]) == proposalId }
                    .map { entry in
                        TallyResult.Entry(
                            decision: parseUInt32(entry["vote_decision"]),
                            amount: parseUInt64(entry["total_value"])
                        )
                    }
                return TallyResult(entries: entries)
            },
            fetchTxConfirmation: { txHash in
                let base = await SvAPIConfigStore.shared.baseURL
                let urlString = "\(base)/shielded-vote/v1/tx/\(txHash)"
                guard let url = URL(string: urlString) else {
                    logger.error("fetchTxConfirmation: invalid URL: \(urlString)")
                    return nil
                }

                let data: Data
                let response: URLResponse
                do {
                    (data, response) = try await httpSession.data(from: url)
                } catch {
                    logger.debug("fetchTxConfirmation: network error: \(error.localizedDescription)")
                    return nil
                }

                guard let http = response as? HTTPURLResponse else {
                    logger.error("fetchTxConfirmation: not an HTTP response")
                    return nil
                }

                // 404 = TX not yet in a block (normal during polling)
                if http.statusCode == 404 {
                    logger.debug("fetchTxConfirmation: 404 (not yet in block) for \(txHash)")
                    return nil
                }

                // 422 = TX included but execution failed (non-zero code).
                // Parse the response to extract the error code/log.
                guard http.statusCode == 200 || http.statusCode == 422 else {
                    let body = String(data: data.prefix(512), encoding: .utf8) ?? "<non-utf8>"
                    logger.debug("fetchTxConfirmation: HTTP \(http.statusCode) for \(txHash) — \(body)")
                    return nil
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let snippet = String(data: data.prefix(512), encoding: .utf8) ?? "<non-utf8>"
                    logger.error("fetchTxConfirmation: JSON parse failed — \(snippet)")
                    return nil
                }

                let height = parseUInt64(json["height"])
                let code = parseUInt32(json["code"])
                let log = json["log"] as? String ?? ""

                var parsedEvents: [TxEvent] = []
                if let events = json["events"] as? [[String: Any]] {
                    for event in events {
                        guard let evType = event["type"] as? String,
                              let attrs = event["attributes"] as? [[String: Any]]
                        else { continue }
                        let parsed = attrs.compactMap { attr -> TxEventAttribute? in
                            guard let key = attr["key"] as? String,
                                  let value = attr["value"] as? String
                            else { return nil }
                            return TxEventAttribute(key: key, value: value)
                        }
                        parsedEvents.append(TxEvent(type: evType, attributes: parsed))
                    }
                }

                let eventSummary = parsedEvents.map { ev in
                    let keys = ev.attributes.map(\.key).joined(separator: ",")
                    return "\(ev.type)[\(keys)]"
                }.joined(separator: "; ")
                logger.debug("fetchTxConfirmation: height=\(height) code=\(code) events=\(eventSummary)")

                return TxConfirmation(height: height, code: code, log: log, events: parsedEvents)
            }
        )
    }
}
