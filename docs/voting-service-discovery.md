# Voting Service Discovery

How zodl-ios discovers vote servers and PIR endpoints at runtime. The wallet implements draft [ZIP 1244](https://github.com/zcash/zips/pull/1244) "Shielded Voting Wallet API".

## Resolution order

1. **Local override** — `voting-config-local.json` bundled in the app's main bundle (DEBUG builds only). Intended for local development against a local chain.
2. **CDN** — [`https://valargroup.github.io/token-holder-voting-config/voting-config.json`](https://valargroup.github.io/token-holder-voting-config/voting-config.json), served via GitHub Pages from [`valargroup/token-holder-voting-config`](https://github.com/valargroup/token-holder-voting-config).

There is no silent fallback. If the local override is malformed, or the CDN is unreachable, returns non-200, decodes to an unsupported shape, or advertises a version the wallet doesn't speak, the wallet routes to the `.configError` screen (`VotingConfigErrorView`) and voting is blocked for the session.

Implementation lives in [`VotingAPIClientLiveKey.swift`](../secant/Sources/Dependencies/VotingAPIClient/VotingAPIClientLiveKey.swift) (`fetchServiceConfig`).

## Config format

Per the [Vote Configuration Format ZIP](https://github.com/zcash/zips/pull/1244):

```json
{
  "config_version": 1,
  "vote_round_id": "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899",
  "vote_servers": [
    {"url": "https://vote-chain-primary.valargroup.org", "label": "primary"},
    {"url": "https://vote-chain-secondary.valargroup.org", "label": "secondary"}
  ],
  "pir_endpoints": [
    {"url": "https://pir.valargroup.org", "label": "PIR primary"}
  ],
  "supported_versions": {
    "pir": ["v0"],
    "vote_protocol": "v0",
    "tally": "v0",
    "vote_server": "v1"
  }
}
```

All fields are required. `JSONDecoder` throws on any missing field, which surfaces as a `.configError` with `VotingConfigError.decodeFailed`. Extra CDN fields are ignored by the wallet unless they are explicitly added to `VotingServiceConfig`.

| Field                | Purpose                                                                                                                                                                     |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `config_version`     | Schema version of this document. Currently 1.                                                                                                                               |
| `vote_round_id`      | Lowercase hex (64 chars) id of the voting round this config is published for. The wallet checks that the chain returns a matching round.                                |
| `vote_servers`       | Chain REST + helper API endpoints. The wallet's first entry serves API traffic; all entries are used for distributing share submissions.                                    |
| `pir_endpoints`      | PIR servers for nullifier-exclusion proofs. The first entry is used.                                                                                                        |
| `supported_versions` | What versions of each component the server speaks. See "Version handling" below.                                                                                            |

## Version handling

[`WalletCapabilities`](../secant/Sources/Dependencies/VotingModels/VotingServiceConfig.swift) declares what this wallet build speaks. On each boot, `validate()` rejects the config if:

- `supported_versions.vote_server ∉ WalletCapabilities.voteServer`
- `supported_versions.vote_protocol ∉ WalletCapabilities.voteProtocol`
- `supported_versions.tally ∉ WalletCapabilities.tally`
- `supported_versions.pir ∩ WalletCapabilities.pir == ∅`

Rejection routes to `.configError`. Per ZIP 1244 §"Version Handling" this is a MUST — the wallet is too old to participate in this round and must be updated.

The `WalletCapabilities` values are compiled into the binary because they are a claim about what the binary actually implements: REST path prefixes in Swift, ZKP circuits in the Rust backend, the PIR scheme version the Rust `pir-client` crate speaks. Moving them to a runtime config would let a wallet accept a config its code can't serve. Bumping a version is a breaking change requiring code updates *and* a bump of `WalletCapabilities`.

## Chain-sourced round data

The CDN config does not carry proposals. After each config fetch, the wallet configures the vote/PIR endpoints and then queries the chain-backed REST API:

- `/shielded-vote/v1/rounds`
- `/shielded-vote/v1/rounds/active`
- `/shielded-vote/v1/round/{round_id}`
- `/shielded-vote/v1/tally-results/{round_id}`

`VoteRound.proposals` is the authoritative source for proposal IDs, titles, descriptions, options, forum links, and result labels. `VoteRound.snapshot_height` and `VoteRound.vote_end_time` are the authoritative snapshot and deadline values used by the wallet. `VoteRound.proposals_hash` remains chain state and can be shown/debugged, but the wallet no longer recomputes it from CDN JSON because the CDN no longer publishes proposal JSON.

On `.allRoundsLoaded`, the wallet still checks that `config.vote_round_id` exists in the chain rounds. A missing match triggers one fresh CDN fetch to recover from a stale config before surfacing `.configError`.

## Failure recovery

- **Transient failure during a round transition** (CDN mid-deploy, cached config now stale): `.allRoundsLoaded` silently auto-retries one fetch per staleness window before surfacing an error. The flag gating the retry resets on every successful binding and on `.initialize`, so each round transition gets its own retry allotment.
- **Permanent failure** (unsupported version, round-id mismatch after retry): terminal for the voting session. The user dismisses and re-enters once they've updated the wallet or the publisher has corrected the CDN/chain state.

## Publisher responsibilities

The config publisher (currently [`valargroup/token-holder-voting-config`](https://github.com/valargroup/token-holder-voting-config)) must:

1. Update `vote_round_id` at or before each on-chain round activates. Any window where the CDN is behind the chain causes transient `.configError`s for wallets booted during that window (auto-retry covers most cases, but the publisher pipeline should be fast).
2. Ensure the configured vote servers expose the chain round and its `VoteRound.proposals` via `/shielded-vote/v1/rounds` and `/shielded-vote/v1/round/{round_id}`.
3. Keep `supported_versions.vote_server` aligned with the REST path prefix the deployed server actually serves (the wallet hits `/shielded-vote/v1/` when `vote_server: "v1"`).

When no round is active, `vote_round_id` may be `"0" * 64`; wallets correctly skip the binding check when the chain also has no rounds.
