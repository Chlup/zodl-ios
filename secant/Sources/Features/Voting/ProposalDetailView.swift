import SwiftUI
import ComposableArchitecture

struct ProposalDetailView: View {
    @Environment(\.colorScheme)
    var colorScheme
    @State private var showUnansweredSheet = false

    let store: StoreOf<Voting>
    let proposal: Proposal

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
            .sheet(isPresented: $showUnansweredSheet) {
                unansweredConfirmationSheet()
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.hidden)
            }
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
            return "\(index + 1) OF \(store.totalProposals)"
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

            Text("View Forum Discussion")
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
        let isLocked = confirmedVote != nil || store.allVoted || store.isBatchSubmitting

        VStack(spacing: 20) {
            voteOptions(confirmedVote: confirmedVote, isLocked: isLocked)
            if !store.allVoted {
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
        return proposal.options + [VoteOption(index: nextIndex, label: "Abstain")]
    }

    @ViewBuilder
    private func voteOptions(confirmedVote: VoteChoice?, isLocked: Bool) -> some View {
        let options = displayOptions
        let draftChoice = store.draftVotes[proposal.id]
        let displayChoice = confirmedVote ?? draftChoice

        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.index) { offset, option in
                let choice = VoteChoice.option(option.index)
                let isSelected = displayChoice == choice

                voteOptionRow(
                    label: option.label,
                    isSelected: isSelected,
                    color: voteOptionColor(for: option.index, total: options.count, colorScheme: colorScheme),
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
            ZashiButton("Back", type: .secondary) {
                store.send(.backToList)
            }

            if !store.isEditingFromReview {
                ZashiButton("Next") {
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

    // MARK: - Unanswered Confirmation Sheet

    @ViewBuilder
    private func unansweredConfirmationSheet() -> some View {
        let count = store.votingRound.proposals.filter { store.draftVotes[$0.id] == nil }.count

        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 24)

            ZStack {
                Circle()
                    .fill(Design.Utility.ErrorRed._500.color(colorScheme).opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Design.Utility.ErrorRed._500.color(colorScheme).opacity(0.8))
            }
            .padding(.bottom, 16)

            Text("Unanswered Questions")
                .zFont(.semiBold, size: 22, style: Design.Text.primary)
                .padding(.bottom, 8)

            Text(
                "You have not responded to \(count) question\(count == 1 ? "" : "s"). "
                + "Confirm to abstain from \(count == 1 ? "this question" : "these questions") or go back to respond."
            )
                .zFont(size: 14, style: Design.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            VStack(spacing: 12) {
                ZashiButton("Confirm", type: .secondary) {
                    showUnansweredSheet = false
                    store.send(.confirmUnanswered)
                }

                ZashiButton("Go back") {
                    showUnansweredSheet = false
                    store.send(.dismissUnanswered)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}
