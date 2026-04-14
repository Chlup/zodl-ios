import SwiftUI
import ComposableArchitecture

struct ConfirmSubmissionView: View {
    @Environment(\.colorScheme) var colorScheme

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection()
                        detailsCard()
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                Spacer(minLength: 0)

                bottomSection()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            .applyScreenBackground()
            .screenTitle(navTitle)
            .zashiBack {
                if !isInFlight { store.send(.backToList) }
            }
        }
    }

    // MARK: - Computed

    private var status: Voting.State.BatchSubmissionStatus {
        store.batchSubmissionStatus
    }

    private var isInFlight: Bool {
        store.isBatchSubmitting
    }

    private var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }

    private var navTitle: String {
        if case .idle = status { return "Confirmation" }
        return "Submission"
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VotingHeaderIcons(isKeystone: store.isKeystoneUser, showCheckmark: isCompleted)
                .padding(.top, 24)
                .padding(.bottom, 24)

            Text(headerTitle)
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(headerSubtitle)
                .zFont(size: 14, style: Design.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerTitle: String {
        switch status {
        case .idle:
            return "Confirm & Submit"
        case .authorizing, .submitting:
            return "Submitting vote..."
        case .completed:
            return "Submission Confirmed!"
        case .failed:
            return "Submission Failed"
        }
    }

    private var headerSubtitle: String {
        switch status {
        case .idle:
            if store.isKeystoneUser {
                // swiftlint:disable:next line_length
                return "Review before signing the voting authorization with your Keystone. This is final. Your vote will be published and cannot be changed."
            }
            return "Review before confirming the voting authorization. This is final. Your vote will be published and cannot be changed."
        case .authorizing, .submitting:
            return "Vote submission is in progress, please don\u{2019}t leave this screen until it is finished."
        case .completed:
            return "Your vote was successfully published and cannot be changed."
        case .failed(let error, _, _):
            return error
        }
    }

    // MARK: - Details Card

    @ViewBuilder
    private func detailsCard() -> some View {
        let isIdle = { if case .idle = status { return true }; return false }()

        VStack(spacing: 0) {
            detailRow(label: "Poll", value: store.votingRound.title)

            Divider()

            if isIdle {
                detailRow(label: "Amount", value: "0.00000001 ZEC")
                Divider()
                detailRow(label: "Fee", value: "0.0001 ZEC")
                Divider()
            } else {
                detailRow(label: "Voting power", value: "\(store.votingWeightZECString) ZEC")
                Divider()
            }

            detailRow(label: "Voting hotkey", value: truncatedHotkey)

            if isIdle {
                Divider()
                memoRow()
            }
        }
        .background(Design.Surfaces.bgSecondary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .zFont(size: 14, style: Design.Text.secondary)
            Spacer()
            Text(value)
                .zFont(.medium, size: 14, style: Design.Text.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func memoRow() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Memo")
                .zFont(size: 14, style: Design.Text.secondary)

            Text("I am authorizing this hotkey managed by my wallet to vote on \(store.votingRound.title) with \(store.votingWeightZECString) ZEC.")
                .zFont(.medium, size: 14, style: Design.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var truncatedHotkey: String {
        guard let address = store.hotkeyAddress, address.count > 11 else {
            return store.hotkeyAddress ?? "–"
        }
        return "\(address.prefix(6))...\(address.suffix(5))"
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private func bottomSection() -> some View {
        switch status {
        case .idle:
            ZashiButton(store.isKeystoneUser ? "Confirm with Keystone" : "Confirm") {
                store.send(.submitAllDrafts)
            }

        case .authorizing:
            VStack(spacing: Design.Spacing._lg) {
                VStack(alignment: .leading, spacing: Design.Spacing._lg) {
                    Text("Authorizing vote...")
                        .zFont(.semiBold, size: 15, style: Design.Text.primary)

                    if case .generating(let progress) = store.delegationProofStatus {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Design.Text.primary.color(colorScheme))
                                    .frame(width: geo.size.width * progress)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 3)

                        Text("\(Int(progress * 100))%")
                            .zFont(.regular, size: 12, style: Design.Text.tertiary)
                    }
                }
                .padding(Design.Spacing._2xl)
                .background(Design.Surfaces.bgSecondary.color(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius._xl))

                ZashiButton("Authorizing...") {}
                    .disabled(true)
            }

        case let .submitting(currentIndex, totalCount, _):
            VStack(spacing: Design.Spacing._lg) {
                VStack(alignment: .leading, spacing: Design.Spacing._lg) {
                    Text("Submitting vote \(currentIndex + 1) of \(totalCount)...")
                        .zFont(.semiBold, size: 15, style: Design.Text.primary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Design.Text.primary.color(colorScheme))
                                .frame(width: geo.size.width * Double(currentIndex + 1) / Double(totalCount))
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        }
                    }
                    .frame(height: 3)

                    if let stepLabel = store.voteSubmissionStepLabel {
                        Text(stepLabel)
                            .zFont(.regular, size: 12, style: Design.Text.tertiary)
                    }
                }
                .padding(Design.Spacing._2xl)
                .background(Design.Surfaces.bgSecondary.color(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius._xl))

                ZashiButton("Submitting vote \(currentIndex + 1) of \(totalCount)") {}
                    .disabled(true)
            }

        case .completed:
            ZashiButton("Done") {
                store.send(.doneTapped)
            }

        case .failed:
            ZashiButton("Dismiss") {
                store.send(.dismissBatchResults)
            }
        }
    }
}
