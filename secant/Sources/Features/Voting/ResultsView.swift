import SwiftUI
import ComposableArchitecture

private func tallyToZEC(_ value: UInt64) -> String {
    let zatoshi = value * ballotDivisor
    let zec = Double(zatoshi) / 100_000_000.0
    return String(format: "%.2f ZEC", zec)
}

private func formatWeightZEC(_ weight: UInt64) -> String {
    let zec = Double(weight) / 100_000_000.0
    return String(format: "%.3f", zec)
}

/// Picks the design-system winner color for an option index. Mirrors
/// `voteOptionColor`'s green/red convention for binary proposals so the visual
/// rhythm matches existing screens, but uses the Figma utility-500 tokens.
private func winnerColorForDecision(
    _ decision: UInt32,
    total: Int,
    colorScheme: ColorScheme
) -> Color {
    if total == 2 {
        return decision == 0
            ? Design.Utility.SuccessGreen._500.color(colorScheme)
            : Design.Utility.ErrorRed._500.color(colorScheme)
    }
    // For 3+ options the design hasn't specified a palette yet — fall back to
    // the existing palette so we don't crash on a multi-option round.
    return voteOptionColor(for: decision, total: total, colorScheme: colorScheme)
}

struct ResultsView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    roundHeader()

                    Text("Results")
                        .zFont(.semiBold, size: 18, style: Design.Text.primary)

                    if store.isLoadingTallyResults {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading results...")
                                .zFont(size: 14, style: Design.Text.secondary)
                        }
                    } else {
                        VStack(spacing: 16) {
                            ForEach(Array(store.votingRound.proposals.enumerated()), id: \.element.id) { _, proposal in
                                proposalResultCard(proposal: proposal)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .applyScreenBackground()
            .screenTitle("Coinholder Polling")
            .zashiBack { store.send(.dismissFlow) }
        }
    }

    // MARK: - Round Header

    @ViewBuilder
    private func roundHeader() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.votingRound.title)
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !store.votingRound.description.isEmpty {
                Text(store.votingRound.description)
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let record = store.voteRecord {
                Text(metaLine(for: record))
                    .zFont(size: 12, style: Design.Text.tertiary)
                    .padding(.top, 4)
            }
        }
    }

    private func metaLine(for record: Voting.VoteRecord) -> String {
        let dateString = record.votedAt.formatted(.dateTime.month(.abbreviated).day())
        return "Voted \(dateString)  ·  Voting Power \(formatWeightZEC(record.votingWeight)) ZEC"
    }

    // MARK: - Proposal Result Card

    @ViewBuilder
    private func proposalResultCard(proposal: Proposal) -> some View {
        let tally = store.tallyResults[proposal.id]
        let rawEntries = tally?.entries ?? []
        // Backfill missing options so they always display (even with 0 votes).
        let knownDecisions = Set(rawEntries.map(\.decision))
        let backfilled: [TallyResult.Entry] = proposal.options.compactMap { option in
            knownDecisions.contains(option.index) ? nil : TallyResult.Entry(decision: option.index, amount: 0)
        }
        let entries = (rawEntries + backfilled).sorted(by: { $0.decision < $1.decision })
        let totalAmount = entries.reduce(UInt64(0)) { $0 + $1.amount }
        let winningEntry = totalAmount > 0 ? entries.max(by: { $0.amount < $1.amount }) : nil

        VStack(alignment: .leading, spacing: 12) {
            // Top row: ZIP pill + Winner pill
            HStack(spacing: 0) {
                ZIPBadge(zipNumber: proposal.zipNumber ?? "ZIP-TBD")
                Spacer()
                winnerBadge(winningEntry: winningEntry, proposal: proposal)
            }

            // Title
            Text(proposal.title)
                .zFont(.semiBold, size: 18, style: Design.Text.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Description (truncated)
            if !proposal.description.isEmpty {
                Text(proposal.description)
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Result bars
            VStack(spacing: 12) {
                ForEach(entries, id: \.decision) { entry in
                    let isWinner = entry.decision == winningEntry?.decision
                    resultBar(
                        label: optionLabel(for: entry.decision, proposal: proposal),
                        amount: entry.amount,
                        total: totalAmount,
                        winnerColor: winnerColorForDecision(
                            entry.decision,
                            total: proposal.options.count,
                            colorScheme: colorScheme
                        ),
                        isWinner: isWinner
                    )
                }
            }
            .padding(.top, 4)

            if entries.isEmpty {
                Text("No votes recorded")
                    .zFont(.medium, size: 13, style: Design.Text.tertiary)
            }

            if totalAmount > 0 {
                Text("Total: \(tallyToZEC(totalAmount))")
                    .zFont(size: 12, style: Design.Text.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Design.Surfaces.bgSecondary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._2xl))
    }

    // MARK: - Winner Badge

    @ViewBuilder
    private func winnerBadge(winningEntry: TallyResult.Entry?, proposal: Proposal) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Design.Text.primary.color(colorScheme))

            HStack(spacing: 4) {
                Text("Winner:")
                    .zFont(.medium, size: 13, style: Design.Text.primary)

                if let winner = winningEntry {
                    let label = optionLabel(for: winner.decision, proposal: proposal)
                    let color = winnerColorForDecision(
                        winner.decision,
                        total: proposal.options.count,
                        colorScheme: colorScheme
                    )
                    Text(label)
                        .zFont(.semiBold, size: 13, color: color)
                } else {
                    Text("—")
                        .zFont(.medium, size: 13, style: Design.Text.tertiary)
                }
            }
        }
    }

    // MARK: - Result Bar

    @ViewBuilder
    private func resultBar(label: String, amount: UInt64, total: UInt64, winnerColor: Color, isWinner: Bool) -> some View {
        let ratio = total > 0 ? Double(amount) / Double(total) : 0
        let labelColor: Color = isWinner ? winnerColor : Design.Text.tertiary.color(colorScheme)
        let fillColor: Color = isWinner ? winnerColor : Design.Text.tertiary.color(colorScheme)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .zFont(.medium, size: 14, color: labelColor)
                Spacer()
                Text(tallyToZEC(amount))
                    .zFont(.medium, size: 14, color: labelColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillColor)
                        .frame(width: max(0, geo.size.width * ratio))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Helpers

    private func optionLabel(for decision: UInt32, proposal: Proposal) -> String {
        if let option = proposal.options.first(where: { $0.index == decision }) {
            return option.label
        }
        // Fallback for proposals without explicit options
        switch decision {
        case 0: return "Support"
        case 1: return "Oppose"
        default: return "Option \(decision)"
        }
    }
}
