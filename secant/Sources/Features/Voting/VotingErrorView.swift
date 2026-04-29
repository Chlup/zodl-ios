import SwiftUI
import ComposableArchitecture

struct VotingErrorView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>
    let errorMessage: String

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Design.Utility.ErrorRed._500.color(colorScheme).opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Design.Utility.ErrorRed._500.color(colorScheme))
                    }

                    // Title
                    Text(localizable: .coinVoteErrorTitle)
                        .zFont(.semiBold, size: 22, style: Design.Text.primary)

                    // Description (already mapped to a user-friendly message by VotingErrorMapper)
                    Text(errorMessage)
                        .zFont(.regular, size: 15, style: Design.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Retry + Dismiss buttons
                VStack(spacing: 12) {
                    ZashiButton(String(localizable: .coinVoteCommonRetry)) {
                        store.send(.initialize)
                    }

                    ZashiButton(String(localizable: .coinVoteCommonDismiss), type: .ghost) {
                        store.send(.dismissFlow)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle(String(localizable: .coinVoteCommonGovernanceTitle))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Design.screenBackground.color(colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.dismissFlow)
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct VotingConfigErrorView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>
    let errorMessage: String

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Design.Utility.ErrorRed._500.color(colorScheme).opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Design.Utility.ErrorRed._500.color(colorScheme))
                    }

                    Text(localizable: .coinVoteConfigErrorTitle)
                        .zFont(.semiBold, size: 22, style: Design.Text.primary)

                    Text(errorMessage)
                        .zFont(.regular, size: 15, style: Design.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Dismiss-only: `.configError` is a terminal session state. The lazy
                // auto-retry in VotingStore.allRoundsLoaded already handles the common
                // transient failure (round transition + publisher update). If the user
                // lands here, they're either in a genuinely incompatible state (needs a
                // wallet update) or a persistent failure (CDN unreachable, tampered
                // config). Retry can't fix those; cold-reentry handles residual transient
                // cases just as well.
                VStack(spacing: 12) {
                    ZashiButton(String(localizable: .coinVoteCommonDismiss), type: .ghost) {
                        store.send(.dismissFlow)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle(String(localizable: .coinVoteCommonGovernanceTitle))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Design.screenBackground.color(colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.dismissFlow)
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
