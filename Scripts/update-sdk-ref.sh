#!/bin/bash
# update-sdk-ref.sh
#
# Maintains ${PROJECT_DIR}/.zodl-sdk-ref.json so that it accurately reflects
# the SDK package reference mode recorded in project.pbxproj (and, in local
# mode, the remote URL + branch of the sibling ../zcash-swift-wallet-sdk git
# working tree).
#
# See 2026-04-20-sdk-ref-sync-design.md for the full design.

set -euo pipefail

fail() {
    echo "error: update-sdk-ref.sh: $1" >&2
    exit 1
}

: "${PROJECT_DIR:?PROJECT_DIR is not set (run from Xcode build phase)}"

PBXPROJ="${PROJECT_DIR}/secant.xcodeproj/project.pbxproj"
REF_FILE="${PROJECT_DIR}/.zodl-sdk-ref.json"
SDK_DIR="${PROJECT_DIR}/../zcash-swift-wallet-sdk"

[[ -f "$PBXPROJ" ]] || fail "project.pbxproj not found at $PBXPROJ"

# ---------------------------------------------------------------------------
# Detect pbxproj mode
# ---------------------------------------------------------------------------
IS_LOCAL=0
IS_REMOTE=0

if grep -q 'XCLocalSwiftPackageReference "\.\./zcash-swift-wallet-sdk"' "$PBXPROJ"; then
    IS_LOCAL=1
fi

if grep -q 'XCRemoteSwiftPackageReference "zcash-swift-wallet-sdk"' "$PBXPROJ" \
    && grep -q 'https://github.com/zcash/zcash-swift-wallet-sdk' "$PBXPROJ"; then
    IS_REMOTE=1
fi

if [[ $IS_LOCAL -eq 1 && $IS_REMOTE -eq 1 ]]; then
    fail "project.pbxproj contains both local and remote SDK package references; cannot determine mode"
fi

if [[ $IS_LOCAL -eq 0 && $IS_REMOTE -eq 0 ]]; then
    fail "could not determine SDK package reference mode from project.pbxproj"
fi

# ---------------------------------------------------------------------------
# Compute desired ref file content
# ---------------------------------------------------------------------------
if [[ $IS_REMOTE -eq 1 ]]; then
    DESIRED='{}'
else
    [[ -d "$SDK_DIR" ]] || fail "local mode but SDK directory not found at $SDK_DIR"
    [[ -d "$SDK_DIR/.git" ]] || fail "local mode but $SDK_DIR is not a git repository"

    CURRENT_BRANCH="$(git -C "$SDK_DIR" branch --show-current)"
    if [[ -z "$CURRENT_BRANCH" ]]; then
        fail "SDK is in detached HEAD state at $SDK_DIR; check out a branch before building"
    fi
    CURRENT_SHA="$(git -C "$SDK_DIR" rev-parse HEAD)"

    REMOTE_URL=""

    # Primary: first remote whose <remote>/<branch> SHA equals CURRENT_SHA.
    while IFS= read -r remote; do
        [[ -z "$remote" ]] && continue
        remote_sha="$(git -C "$SDK_DIR" rev-parse "${remote}/${CURRENT_BRANCH}" 2>/dev/null || true)"
        if [[ -n "$remote_sha" && "$remote_sha" == "$CURRENT_SHA" ]]; then
            REMOTE_URL="$(git -C "$SDK_DIR" remote get-url "$remote")"
            break
        fi
    done < <(git -C "$SDK_DIR" remote)

    # Fallback 1: exactly one remote has a branch with this name.
    if [[ -z "$REMOTE_URL" ]]; then
        matches=()
        while IFS= read -r remote; do
            [[ -z "$remote" ]] && continue
            if git -C "$SDK_DIR" rev-parse --verify --quiet "${remote}/${CURRENT_BRANCH}" >/dev/null 2>&1; then
                matches+=("$remote")
            fi
        done < <(git -C "$SDK_DIR" remote)

        if [[ ${#matches[@]} -eq 1 ]]; then
            REMOTE_URL="$(git -C "$SDK_DIR" remote get-url "${matches[0]}")"
        fi
    fi

    if [[ -z "$REMOTE_URL" ]]; then
        fail "SDK branch '${CURRENT_BRANCH}' is not present on any registered remote. Push your branch to a fork and try again."
    fi

    DESIRED=$(printf '{\n  "repoURL": "%s",\n  "branch": "%s"\n}' "$REMOTE_URL" "$CURRENT_BRANCH")
fi

# ---------------------------------------------------------------------------
# Write only if changed (idempotent)
# ---------------------------------------------------------------------------
CURRENT=""
if [[ -f "$REF_FILE" ]]; then
    CURRENT="$(cat "$REF_FILE")"
fi

if [[ "$CURRENT" != "$DESIRED" ]]; then
    printf '%s\n' "$DESIRED" > "$REF_FILE"
    echo "update-sdk-ref.sh: wrote $REF_FILE"
else
    echo "update-sdk-ref.sh: $REF_FILE is already up to date"
fi
