import SwiftUI

// MARK: - Voting Header Icons

struct VotingHeaderIcons: View {
    @Environment(\.colorScheme) var colorScheme
    var isKeystone: Bool = false
    var showCheckmark: Bool = false

    var body: some View {
        HStack(spacing: -4) {
            if isKeystone {
                Asset.Assets.Brandmarks.brandmarkKeystone.image
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Design.Text.primary.color(colorScheme))
                        .frame(width: 48, height: 48)
                    Asset.Assets.zashiLogo.image
                        .zImage(size: 22, color: Design.Surfaces.bgPrimary.color(colorScheme))
                }
            }

            if showCheckmark {
                ZStack {
                    Circle()
                        .fill(Design.Utility.SuccessGreen._500.color(colorScheme).opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Design.Utility.SuccessGreen._500.color(colorScheme))
                }
                .zIndex(1)
            } else {
                ZStack {
                    Circle()
                        .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                        .frame(width: 48, height: 48)
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Design.Text.primary.color(colorScheme))
                }
            }
        }
    }
}

// MARK: - Prototype Banner

struct PrototypeBanner: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.caption)
            Text("Prototype \u{2014} some features are mocked")
                .font(.caption)
        }
        .foregroundStyle(Design.Surfaces.bgPrimary.color(colorScheme))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Utility.Purple._500.color(colorScheme).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Vote Option Palette

/// Color for a vote option index. For 2-option proposals this preserves the classic
/// green (Support) / red (Oppose) look; for 3+ options it cycles through a palette.
func voteOptionColor(for index: UInt32, total: Int, colorScheme: ColorScheme) -> Color {
    if total == 2 {
        return index == 0
            ? Design.Utility.SuccessGreen._500.color(colorScheme)
            : Design.Utility.ErrorRed._500.color(colorScheme)
    }
    let palette: [Color] = [
        Design.Utility.SuccessGreen._500.color(colorScheme),
        Design.Utility.ErrorRed._500.color(colorScheme),
        Design.Utility.HyperBlue._500.color(colorScheme),
        Design.Utility.Purple._500.color(colorScheme),
        Design.Utility.WarningYellow._500.color(colorScheme),
        Design.Utility.Indigo._500.color(colorScheme),
        Design.Utility.Brand._500.color(colorScheme),
        Design.Utility.Gray._500.color(colorScheme)
    ]
    return palette[Int(index) % palette.count]
}

/// SF Symbol for a vote option index. For 2-option proposals this preserves the classic
/// thumbs-up / thumbs-down icons; for 3+ options it uses numbered circles.
func voteOptionIcon(for index: UInt32, total: Int) -> String {
    if total == 2 { return index == 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill" }
    return "\(index + 1).circle.fill"
}

// MARK: - Vote Badge (for proposal cards)

/// Resolves a `VoteChoice` to a human label and color for display on proposal cards.
func voteBadgeInfo(for choice: VoteChoice, proposal: Proposal, colorScheme: ColorScheme) -> (label: String, color: Color) {
    let options = proposal.options
    let hasAbstain = options.contains { $0.label.localizedCaseInsensitiveContains("abstain") }
    let synthesizedAbstainIndex: UInt32? = hasAbstain ? nil : (options.map(\.index).max() ?? 0) + 1
    let abstainBlue = Design.Utility.HyperBlue._700.color(colorScheme)

    if let syntheticIdx = synthesizedAbstainIndex, choice.index == syntheticIdx {
        return ("Abstain", abstainBlue)
    }

    if let matched = options.first(where: { $0.index == choice.index }) {
        if matched.label.localizedCaseInsensitiveContains("abstain") {
            return (matched.label, abstainBlue)
        }
        let color = voteOptionColor(for: matched.index, total: options.count, colorScheme: colorScheme)
        return (matched.label, color)
    }

    return ("Voted", Design.Utility.Gray._500.color(colorScheme))
}

struct VoteBadgePill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Vote Chip

struct VoteChip: View {
    @Environment(\.colorScheme) var colorScheme
    let choice: VoteChoice?
    var label: String?
    var color: Color?

    var body: some View {
        Text(resolvedLabel)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(choice != nil ? Design.Surfaces.bgPrimary.color(colorScheme) : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(resolvedBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: choice == nil ? 1 : 0)
            )
    }

    private var resolvedLabel: String {
        if let label { return label }
        guard choice != nil else { return "Not voted" }
        return "Voted"
    }

    private var resolvedBackground: Color {
        if let color { return color }
        guard choice != nil else { return .clear }
        return .gray
    }

    private var borderColor: Color {
        choice == nil ? Color.secondary.opacity(0.3) : .clear
    }
}

// MARK: - ZIP Badge

struct ZIPBadge: View {
    let zipNumber: String

    var body: some View {
        Text(zipNumber)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - ZKP Status Banner

struct ZKPStatusBanner: View {
    @Environment(\.colorScheme) var colorScheme
    let proofStatus: ProofStatus
    var isPreparingWitnesses: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            switch proofStatus {
            case .notStarted:
                EmptyView()
            case .generating(let progress):
                ProgressView()
                    .scaleEffect(0.8)
                if isPreparingWitnesses {
                    Text("Preparing note witnesses...")
                        .font(.caption)
                } else {
                    Text("Preparing voting authorization... \(Int(progress * 100))%")
                        .font(.caption)
                }
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Design.Utility.SuccessGreen._500.color(colorScheme))
                    .font(.caption)
                Text("Ready to vote")
                    .font(.caption)
            case .failed(let error):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Design.Utility.WarningYellow._500.color(colorScheme))
                    .font(.caption)
                Text(error)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Vote Commitment Stub Card

struct VoteCommitmentStubCard: View {
    let bundle: VoteCommitmentBundle
    let txHash: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prototype VC Stub")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("commitment: \(bundle.voteCommitment.shortHex)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Text("van nullifier: \(bundle.vanNullifier.shortHex)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if let txHash, !txHash.isEmpty {
                Text("tx: \(txHash)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Share Submission Status

struct ShareSubmissionStatus: View {
    @Environment(\.colorScheme) var colorScheme
    let confirmed: Int
    let total: Int
    let onInfoTapped: () -> Void

    private var isComplete: Bool {
        confirmed >= total && total > 0
    }

    var body: some View {
        HStack(spacing: 6) {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Design.Utility.SuccessGreen._500.color(colorScheme))
                    .font(.caption)
                Text("Vote confirmed")
                    .font(.caption)
                    .foregroundStyle(Design.Utility.SuccessGreen._500.color(colorScheme))
            } else {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Design.Utility.WarningYellow._500.color(colorScheme))
                    .font(.caption)
                Text("Submitting vote")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onInfoTapped) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Share Info Sheet

struct ShareInfoSheet: View {
    let allConfirmed: Bool
    let estimatedCompletion: Date?
    /// Duration of the voting round in seconds (used to decide time rounding).
    let roundDuration: TimeInterval
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    /// Format the estimated completion date. If the round is longer than 1 hour,
    /// round the time up to the nearest 10 minutes.
    private var formattedCompletion: String? {
        guard let date = estimatedCompletion, date > Date() else { return nil }
        let displayDate: Date
        if roundDuration > 3600 {
            // Round up to nearest 10 minutes
            let cal = Calendar.current
            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let minute = components.minute ?? 0
            let roundedMinute = ((minute + 9) / 10) * 10
            if roundedMinute >= 60 {
                // Rolled over to next hour
                var adjusted = components
                adjusted.minute = 0
                if let base = cal.date(from: adjusted) {
                    displayDate = cal.date(byAdding: .hour, value: 1, to: base) ?? date
                } else {
                    displayDate = date
                }
            } else {
                var adjusted = components
                adjusted.minute = roundedMinute
                displayDate = cal.date(from: adjusted) ?? date
            }
        } else {
            displayDate = date
        }
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: displayDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Status icon
            ZStack {
                Circle()
                    .fill(allConfirmed
                          ? Design.Utility.SuccessGreen._500.color(colorScheme).opacity(0.12)
                          : Design.Utility.WarningYellow._500.color(colorScheme).opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: allConfirmed ? "checkmark.shield.fill" : "lock.shield")
                    .font(.system(size: 24))
                    .foregroundStyle(allConfirmed
                                    ? Design.Utility.SuccessGreen._500.color(colorScheme)
                                    : Design.Utility.WarningYellow._500.color(colorScheme))
            }
            .padding(.bottom, 16)

            // Title
            Text(allConfirmed ? "Vote Confirmed" : "Submitting Vote")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.bottom, 4)

            // Subtitle
            Text(allConfirmed
                 ? "All shares have been confirmed on-chain."
                 : "Your vote is being submitted in multiple shares to protect your privacy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

            // Estimated completion
            if !allConfirmed {
                if let formatted = formattedCompletion {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.subheadline)
                            .foregroundStyle(Design.Utility.WarningYellow._500.color(colorScheme))
                        Text("Expected by \(formatted)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                } else if estimatedCompletion != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Finishing up…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }

            // Explanation card
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "eye.slash")
                    .font(.subheadline)
                    .foregroundStyle(Design.Utility.WarningYellow._500.color(colorScheme))
                    .padding(.top, 2)

                Text("Each share is sent at different times across various servers throughout the vote period to further protect your privacy. Each value is encrypted, and only the total amount across all voters will be revealed at the end of the vote period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Design.Surfaces.bgTertiary.color(colorScheme))
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

private extension Data {
    var shortHex: String {
        let hex = map { String(format: "%02x", $0) }.joined()
        if hex.count <= 16 {
            return hex
        }
        let prefix = hex.prefix(8)
        let suffix = hex.suffix(8)
        return "\(prefix)...\(suffix)"
    }
}
