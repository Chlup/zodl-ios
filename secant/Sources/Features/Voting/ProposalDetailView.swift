import SwiftUI
import ComposableArchitecture

struct ProposalDetailView: View {
    @Environment(\.colorScheme)
    var colorScheme
    @State private var showUnansweredSheet = false

    let store: StoreOf<Voting>
    let proposal: VotingProposal

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    contentSection()
                }

                bottomSection()
            }
            .applyScreenBackground()
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .votingSheet(
                isPresented: $showUnansweredSheet,
                title: String(localizable: .coinVoteProposalDetailUnansweredTitle),
                message: unansweredMessage,
                primary: .init(title: String(localizable: .coinVoteCommonGoBack), style: .primary) {
                    showUnansweredSheet = false
                    store.send(.dismissUnanswered)
                },
                secondary: .init(title: String(localizable: .coinVoteCommonConfirm), style: .secondary) {
                    showUnansweredSheet = false
                    store.send(.confirmUnanswered)
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.backToList)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Design.Text.primary.color(colorScheme))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(positionLabel)
                        .zFont(.semiBold, size: 14, style: Design.Text.primary)
                }
            }
        }
    }

    private var positionLabel: String {
        if let index = store.detailProposalIndex {
            return String(
                localizable: .coinVoteProposalDetailPosition(
                    String(index + 1),
                    String(store.totalProposals)
                )
            )
        }
        return ""
    }

    // MARK: - Content

    @ViewBuilder
    private func contentSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(proposal.title)
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .tracking(-0.384)
                .fixedSize(horizontal: false, vertical: true)

            if !proposal.description.isEmpty {
                Text(proposal.description)
                    .zFont(size: 16, style: Design.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            forumLink()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Forum Link

    @ViewBuilder
    private func forumLink() -> some View {
        let content = HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                    .frame(width: 36, height: 36)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Design.Text.primary.color(colorScheme))
            }

            Text(localizable: .coinVoteProposalDetailViewForumDiscussion)
                .zFont(.medium, size: 16, style: Design.Text.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.Text.tertiary.color(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )

        if let url = proposal.forumURL {
            Link(destination: url) { content }
        } else {
            content
                .opacity(0.5)
        }
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private func bottomSection() -> some View {
        let confirmedVote = store.votes[proposal.id]
        let isSubmitted = store.voteRecord != nil
        let isLocked = confirmedVote != nil || store.allVoted || store.isBatchSubmitting || isSubmitted

        VStack(spacing: 20) {
            voteOptions(isLocked: isLocked)
            if !store.allVoted && !isSubmitted {
                navigationButtons()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Vote Options

    /// Options including an Abstain fallback when the data doesn't provide one.
    private var displayOptions: [VoteOption] {
        let hasAbstain = proposal.options.contains {
            $0.label.localizedCaseInsensitiveContains("abstain")
        }
        if hasAbstain || proposal.options.isEmpty {
            return proposal.options
        }
        let nextIndex = (proposal.options.map(\.index).max() ?? 0) + 1
        return proposal.options + [VoteOption(index: nextIndex, label: String(localizable: .coinVoteCommonAbstain))]
    }

    @ViewBuilder
    private func voteOptions(isLocked: Bool) -> some View {
        let options = displayOptions
        let displayChoice = store.effectiveChoices[proposal.id]

        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.index) { offset, option in
                let choice = VoteChoice.option(option.index)
                let isSelected = displayChoice == choice

                voteOptionRow(
                    label: option.label,
                    isSelected: isSelected,
                    color: voteOptionColor(for: option, total: options.count, colorScheme: colorScheme),
                    isLocked: isLocked
                ) {
                    impactFeedback.impactOccurred()
                    store.send(.castVote(proposalId: proposal.id, choice: choice))
                }

                // Divider between unselected adjacent options
                if offset < options.count - 1 {
                    let nextOption = options[offset + 1]
                    let nextSelected = displayChoice == VoteChoice.option(nextOption.index)
                    if !isSelected && !nextSelected {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func voteOptionRow(
        label: String,
        isSelected: Bool,
        color: Color,
        isLocked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .zFont(.medium, size: 16,
                           color: isSelected ? Design.Surfaces.bgPrimary.color(colorScheme) : Design.Text.primary.color(colorScheme))

                Spacer()

                // Checkbox
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Design.Text.primary.color(colorScheme))
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Design.Surfaces.bgPrimary.color(colorScheme))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius._xl))
        }
        .disabled(isLocked)
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private func navigationButtons() -> some View {
        HStack(spacing: 12) {
            if store.isEditingFromReview {
                ZashiButton(String(localizable: .coinVoteCommonCancel), type: .secondary) {
                    store.send(.cancelEdit)
                }
                ZashiButton(String(localizable: .coinVoteCommonSave)) {
                    store.send(.saveEdit)
                }
            } else {
                ZashiButton(String(localizable: .coinVoteCommonBack), type: .secondary) {
                    store.send(.backToList)
                }
                ZashiButton(String(localizable: .coinVoteCommonNext)) {
                    let isLast = store.detailProposalIndex == store.totalProposals - 1
                    if isLast && !store.allDrafted {
                        showUnansweredSheet = true
                    } else {
                        store.send(.nextProposalDetail)
                    }
                }
            }
        }
    }

    private var unansweredMessage: String {
        let count = store.votingRound.proposals.filter { store.draftVotes[$0.id] == nil }.count
        if count == 1 {
            return String(localizable: .coinVoteProposalDetailUnansweredMessageSingle(String(count)))
        }
        return String(localizable: .coinVoteProposalDetailUnansweredMessageMultiple(String(count)))
    }
}
