import SwiftUI
import ComposableArchitecture

struct PollsListView: View {
    @Environment(\.colorScheme)
    var colorScheme
    @State private var loadErrorSheetPresented = true
    @State private var dismissFlowAfterLoadErrorSheetDismiss = false

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            let visiblePolls = self.visiblePolls
            ScrollView {
                VStack(spacing: 16) {
                    if store.pollsLoadError || visiblePolls.isEmpty {
                        PollsListSkeletonCard()
                    } else {
                        // Newest polls first. allRounds is stored ascending so the
                        // assigned round numbers stay sane (round 1 = oldest), but
                        // the list shows the latest at the top.
                        ForEach(Array(visiblePolls.reversed()), id: \.id) { item in
                            pollCard(for: item)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .applyScreenBackground()
            .screenTitle(String(localizable: .coinVoteCommonScreenTitle))
            .zashiBack { store.send(.dismissFlow) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.send(.openConfigSettings)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .zForegroundColor(Design.Text.primary)
                    }
                    .accessibilityLabel("Voting chain config")
                }
            }
            .votingSheet(
                isPresented: loadErrorBinding,
                title: String(localizable: .coinVotePollsListLoadErrorTitle),
                message: String(localizable: .coinVotePollsListLoadErrorMessage),
                primary: .init(title: String(localizable: .coinVoteCommonTryAgain), style: .primary) {
                    store.send(.retryLoadRounds)
                },
                secondary: .init(title: String(localizable: .coinVoteCommonGoBack), style: .secondary) {
                    dismissFlowAfterLoadErrorSheetDismiss = true
                    loadErrorSheetPresented = false
                },
                onDismiss: {
                    guard dismissFlowAfterLoadErrorSheetDismiss else { return }
                    dismissFlowAfterLoadErrorSheetDismiss = false
                    store.send(.dismissFlow)
                }
            )
        }
    }

    private var visiblePolls: [Voting.State.RoundListItem] {
        guard store.isOnDefaultConfig else {
            return store.allRounds
        }
        return store.allRounds.filter { store.zodlEndorsedRoundIds.contains($0.id) }
    }

    // MARK: - Load Error Sheet

    private var loadErrorBinding: Binding<Bool> {
        Binding(
            get: { loadErrorSheetPresented && store.pollsLoadError },
            // Drag-dismiss mirrors Go back: exit the voting flow rather than
            // leave the user on a stale/empty list with no action to take.
            set: { newValue in
                if newValue {
                    loadErrorSheetPresented = true
                } else if store.pollsLoadError {
                    dismissFlowAfterLoadErrorSheetDismiss = true
                    loadErrorSheetPresented = false
                }
            }
        )
    }

    // MARK: - Card

    private enum CardState {
        case active     // round is active and the user has not voted yet
        case voted      // round is active and the user has already confirmed
        case closed     // round is finalized or tallying — read-only results
    }

    private func cardState(for item: Voting.State.RoundListItem) -> CardState {
        switch item.session.status {
        case .active:
            return store.voteRecords[item.id] != nil ? .voted : .active
        case .tallying, .finalized, .unspecified:
            return .closed
        }
    }

    @ViewBuilder
    private func pollCard(for item: Voting.State.RoundListItem) -> some View {
        let state = cardState(for: item)
        let totalProposals = item.session.proposals.count
        let votedCount = votedProposalCount(for: item, totalProposals: totalProposals)

        VStack(alignment: .leading, spacing: 16) {
            // Top row: state pill + closes/closed date
            HStack(spacing: 0) {
                pollStatusPill(state)
                Spacer()
                Text(dateLabel(for: state, item: item))
                    .zFont(.medium, size: 14, style: Design.Text.tertiary)
                    .tracking(-0.224) // -1.6% × 14pt
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)
                    .tracking(-0.256) // -1.6% × 16pt
                    .fixedSize(horizontal: false, vertical: true)

                if totalProposals > 0 {
                    votedIndicator(votedCount: votedCount, total: totalProposals)
                }
            }

            issuerTrustIndicator(for: item)

            // "Poll Description" label + description
            if !item.session.description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizable: .coinVoteCommonPollDescription)
                        .zFont(.medium, size: 14, style: Design.Text.tertiary)
                        .tracking(-0.224)

                    Text(item.session.description)
                        .zFont(.medium, size: 14, style: Design.Text.primary)
                        .tracking(-0.224)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Action button (varies by state)
            actionButton(for: state, item: item)
                .padding(.top, 4)
        }
        .padding(Design.Spacing._xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )
        // Layered card shadow from Figma using shadow-sm = rgba(35, 31, 32, 0.04).
        // SwiftUI's shadow radius is roughly half of Figma's blur and spread
        // isn't supported, so the layer values are approximations.
        .shadow(color: Self.shadowSm, radius: 12, x: 0, y: 24)
        .shadow(color: Self.shadowSm, radius: 1.5, x: 0, y: 3)
        .shadow(color: Self.shadowSm, radius: 0.5, x: 0, y: 1)
    }

    private static let shadowSm = Color(red: 35.0 / 255.0, green: 31.0 / 255.0, blue: 32.0 / 255.0).opacity(0.04)

    @ViewBuilder
    private func issuerTrustIndicator(for item: Voting.State.RoundListItem) -> some View {
        if store.isOnDefaultConfig, store.zodlEndorsedRoundIds.contains(item.id) {
            zodlTrustIndicator(fontSize: 14, iconSize: 16)
        } else if !store.isOnDefaultConfig {
            unverifiedIssuerIndicator(fontSize: 12, iconSize: 14)
        }
    }

    private func zodlTrustIndicator(fontSize: CGFloat, iconSize: CGFloat) -> some View {
        let backdropSize = iconSize + 8
        let zodlTextColor = colorScheme == .light ? Color.black : Design.Text.primary.color(colorScheme)

        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: backdropSize, height: backdropSize)

                Asset.Assets.zashiLogo.image
                    .zImage(size: iconSize, color: .white)
            }

            Text("Zodl")
                .zFont(.medium, size: fontSize, color: zodlTextColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Verified by Zodl"))
    }

    private func unverifiedIssuerIndicator(fontSize: CGFloat, iconSize: CGFloat) -> some View {
        let foregroundColor = Design.Utility.WarningYellow._700.color(colorScheme)
        let backgroundColor = Design.Utility.WarningYellow._50.color(colorScheme)

        return HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: iconSize, weight: .medium))

            Text("Unverified Poll")
                .zFont(.medium, size: fontSize, color: foregroundColor)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Unverified Poll"))
    }

    /// Per-round count of proposals the user voted on. Falls back to the total
    /// proposal count for legacy records (written before proposalCount was
    /// stored), since the batch flow used to vote on every proposal at once.
    private func votedProposalCount(for item: Voting.State.RoundListItem, totalProposals: Int) -> Int {
        guard let record = store.voteRecords[item.id] else { return 0 }
        return record.proposalCount > 0 ? record.proposalCount : totalProposals
    }

    // MARK: - Voted Indicator

    @ViewBuilder
    private func votedIndicator(votedCount: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Text(localizable: .coinVotePollsListVotedCount(String(votedCount), String(total)))
                .zFont(.medium, size: 14, style: Design.Text.primary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(
                            index < votedCount
                                ? Design.Utility.SuccessGreen._500.color(colorScheme)
                                : Design.Surfaces.bgTertiary.color(colorScheme)
                        )
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Status Pill

    @ViewBuilder
    private func pollStatusPill(_ state: CardState) -> some View {
        let style = pollStatusPillStyle(for: state)

        HStack(spacing: 6) {
            Image(systemName: style.iconSystemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(style.foregroundColor)

            Text(style.label)
                .zFont(.medium, size: 14, color: style.foregroundColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(style.backgroundColor)
        .clipShape(Capsule())
    }

    private func pollStatusPillStyle(for state: CardState) -> PollStatusPillStyle {
        switch state {
        case .active:
            return PollStatusPillStyle(
                iconSystemName: "clock",
                label: String(localizable: .coinVotePollsListStatusActive),
                foregroundColor: Design.Utility.SuccessGreen._700.color(colorScheme),
                backgroundColor: Design.Utility.SuccessGreen._50.color(colorScheme)
            )
        case .voted:
            return PollStatusPillStyle(
                iconSystemName: "checkmark",
                label: String(localizable: .coinVoteCommonVoted),
                foregroundColor: Design.Utility.SuccessGreen._700.color(colorScheme),
                backgroundColor: Design.Utility.SuccessGreen._50.color(colorScheme)
            )
        case .closed:
            return PollStatusPillStyle(
                iconSystemName: "clock",
                label: String(localizable: .coinVotePollsListStatusClosed),
                foregroundColor: Design.Utility.ErrorRed._700.color(colorScheme),
                backgroundColor: Design.Utility.ErrorRed._50.color(colorScheme)
            )
        }
    }

    // MARK: - Date Label

    private func dateLabel(for state: CardState, item: Voting.State.RoundListItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let formatted = formatter.string(from: item.session.voteEndTime)
        switch state {
        case .active, .voted:
            return String(localizable: .coinVotePollsListDateCloses(formatted))
        case .closed:
            return String(localizable: .coinVotePollsListDateClosed(formatted))
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(for state: CardState, item: Voting.State.RoundListItem) -> some View {
        switch state {
        case .active:
            ZashiButton(String(localizable: .coinVotePollsListEnterPoll), infinityWidth: false) {
                store.send(.roundTapped(item.id))
            }
        case .voted:
            ZashiButton(String(localizable: .coinVotePollsListViewMyVotes), infinityWidth: false) {
                store.send(.viewMyVotesTapped(roundId: item.id))
            }
        case .closed:
            ZashiButton(String(localizable: .coinVoteCommonViewResults), type: .tertiary, infinityWidth: false) {
                store.send(.roundTapped(item.id))
            }
        }
    }
}

struct PollsListSkeletonCard: View {
    @Environment(\.colorScheme)
    var colorScheme

    var body: some View {
        let barFill = Design.Surfaces.bgTertiary.color(colorScheme)
        return VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 4).fill(barFill).frame(width: 80, height: 12)
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 4).fill(barFill).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).fill(barFill).frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(barFill)
                    .frame(width: 240, height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            RoundedRectangle(cornerRadius: 4).fill(barFill).frame(width: 60, height: 12)
        }
        .padding(Design.Spacing._xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
    }
}

private struct PollStatusPillStyle {
    let iconSystemName: String
    let label: String
    let foregroundColor: Color
    let backgroundColor: Color
}
