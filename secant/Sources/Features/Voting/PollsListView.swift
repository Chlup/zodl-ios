import SwiftUI
import ComposableArchitecture

struct PollsListView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 16) {
                    if store.pollsLoadError {
                        // Skeleton placeholder behind the "Couldn't load polls"
                        // sheet, per the Figma. Single card with gray bars so
                        // the surface doesn't read as empty.
                        pollsSkeletonCard
                    } else {
                        // Newest polls first. allRounds is stored ascending so the
                        // assigned round numbers stay sane (round 1 = oldest), but
                        // the list shows the latest at the top.
                        ForEach(Array(store.allRounds.reversed()), id: \.id) { item in
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
            .votingSheet(
                isPresented: loadErrorBinding,
                title: String(localizable: .coinVotePollsListLoadErrorTitle),
                message: String(localizable: .coinVotePollsListLoadErrorMessage),
                primary: .init(title: String(localizable: .coinVoteCommonTryAgain), style: .primary) {
                    store.send(.retryLoadRounds)
                },
                secondary: .init(title: String(localizable: .coinVoteCommonGoBack), style: .secondary) {
                    store.send(.dismissFlow)
                }
            )
        }
    }

    // MARK: - Skeleton Placeholder

    private var pollsSkeletonCard: some View {
        let barFill = Design.Surfaces.bgTertiary.color(colorScheme)
        return VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 4).fill(barFill).frame(width: 80, height: 12)
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 4).fill(barFill).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).fill(barFill).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).fill(barFill).frame(width: 240, height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            RoundedRectangle(cornerRadius: 4).fill(barFill).frame(width: 60, height: 12)
        }
        .padding(Design.Spacing._xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
    }

    private var loadErrorBinding: Binding<Bool> {
        Binding(
            get: { store.pollsLoadError },
            // Drag-dismiss mirrors Go back: exit the voting flow rather than
            // leave the user on a stale/empty list with no action to take.
            set: { newValue in
                if !newValue { store.send(.dismissFlow) }
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

            // Title
            Text(item.title)
                .zFont(.semiBold, size: 16, style: Design.Text.primary)
                .tracking(-0.256) // -1.6% × 16pt
                .fixedSize(horizontal: false, vertical: true)

            // "X of Y voted" indicator — shown on Voted and Closed cards
            // whenever the user has actually voted in this round. Active
            // cards (no vote yet) skip it.
            if (state == .voted || state == .closed)
                && store.voteRecords[item.id] != nil
                && totalProposals > 0 {
                votedIndicator(votedCount: votedCount, total: totalProposals)
            }

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
        let (icon, label, fg, bg): (String, String, Color, Color) = {
            switch state {
            case .active:
                return (
                    "clock",
                    String(localizable: .coinVotePollsListStatusActive),
                    Design.Utility.SuccessGreen._700.color(colorScheme),
                    Design.Utility.SuccessGreen._50.color(colorScheme)
                )
            case .voted:
                return (
                    "checkmark",
                    String(localizable: .coinVoteCommonVoted),
                    Design.Utility.SuccessGreen._700.color(colorScheme),
                    Design.Utility.SuccessGreen._50.color(colorScheme)
                )
            case .closed:
                return (
                    "clock",
                    String(localizable: .coinVotePollsListStatusClosed),
                    Design.Utility.ErrorRed._700.color(colorScheme),
                    Design.Utility.ErrorRed._50.color(colorScheme)
                )
            }
        }()

        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(fg)

            Text(label)
                .zFont(.medium, size: 14, color: fg)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(bg)
        .clipShape(Capsule())
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
