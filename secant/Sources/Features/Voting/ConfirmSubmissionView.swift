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
            .votingSheet(
                isPresented: authorizationFailedBinding,
                title: String(localizable: .coinVoteConfirmSubmissionAuthorizationFailedTitle),
                message: String(localizable: .coinVoteConfirmSubmissionAuthorizationFailedMessage),
                primary: .init(title: String(localizable: .coinVoteCommonTryAgain), style: .primary) {
                    store.send(.retryBatchSubmission)
                },
                secondary: .init(title: String(localizable: .coinVoteCommonCancel), style: .secondary) {
                    store.send(.dismissBatchResults)
                }
            )
            .votingSheet(
                isPresented: submissionFailedBinding,
                title: String(localizable: .coinVoteConfirmSubmissionSubmissionFailedTitle),
                message: String(localizable: .coinVoteConfirmSubmissionSubmissionFailedMessage),
                primary: .init(title: String(localizable: .coinVoteCommonTryAgain), style: .primary) {
                    store.send(.retryBatchSubmission)
                },
                secondary: .init(title: String(localizable: .coinVoteCommonCancel), style: .secondary) {
                    store.send(.dismissBatchResults)
                }
            )
        }
    }

    // MARK: - Sheet bindings

    private var authorizationFailedBinding: Binding<Bool> {
        Binding(
            get: { if case .authorizationFailed = status { return true } else { return false } },
            set: { newValue in
                if !newValue { store.send(.dismissBatchResults) }
            }
        )
    }

    private var submissionFailedBinding: Binding<Bool> {
        Binding(
            get: { if case .submissionFailed = status { return true } else { return false } },
            set: { newValue in
                if !newValue { store.send(.dismissBatchResults) }
            }
        )
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
        if case .idle = status {
            return String(localizable: .coinVoteCommonConfirmation)
        }
        return String(localizable: .coinVoteCommonSubmission)
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
            return String(localizable: .coinVoteConfirmSubmissionHeaderTitleIdle)
        case .authorizing, .submitting, .authorizationFailed, .submissionFailed:
            // Failure overlays (.authorizationFailed / .submissionFailed) keep
            // the in-progress appearance underneath while the sheet drives UX.
            return String(localizable: .coinVoteConfirmSubmissionHeaderTitleSubmitting)
        case .completed:
            return String(localizable: .coinVoteConfirmSubmissionHeaderTitleCompleted)
        }
    }

    private var headerSubtitle: String {
        switch status {
        case .idle:
            if store.isKeystoneUser {
                return String(localizable: .coinVoteConfirmSubmissionHeaderSubtitleIdleKeystone)
            }
            return String(localizable: .coinVoteConfirmSubmissionHeaderSubtitleIdle)
        case .authorizing, .submitting, .authorizationFailed, .submissionFailed:
            return String(localizable: .coinVoteConfirmSubmissionHeaderSubtitleSubmitting)
        case .completed:
            return String(localizable: .coinVoteConfirmSubmissionHeaderSubtitleCompleted)
        }
    }

    // MARK: - Details Card

    @ViewBuilder
    private func detailsCard() -> some View {
        let isIdle = { if case .idle = status { return true }; return false }()

        VStack(spacing: 0) {
            detailRow(label: String(localizable: .coinVoteConfirmSubmissionDetailPoll), value: store.votingRound.title)

            Divider()

            if isIdle {
                detailRow(
                    label: String(localizable: .coinVoteConfirmSubmissionDetailAmount),
                    value: String(localizable: .coinVoteConfirmSubmissionDetailAmountValue)
                )
                Divider()
                detailRow(
                    label: String(localizable: .coinVoteConfirmSubmissionDetailFee),
                    value: String(localizable: .coinVoteConfirmSubmissionDetailFeeValue)
                )
                Divider()
            } else {
                detailRow(
                    label: String(localizable: .coinVoteConfirmSubmissionDetailVotingPower),
                    value: String(localizable: .coinVoteConfirmSubmissionDetailVotingPowerValue(store.votingWeightZECString))
                )
                Divider()
            }

            detailRow(label: String(localizable: .coinVoteConfirmSubmissionDetailVotingHotkey), value: truncatedHotkey)

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
            Text(localizable: .coinVoteConfirmSubmissionDetailMemo)
                .zFont(size: 14, style: Design.Text.secondary)

            Text(localizable: .coinVoteConfirmSubmissionMemoMessage(store.votingRound.title, store.votingWeightZECString))
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

    // MARK: - Progress

    // Unified 0-1 fill across authorization + all submissions so the bar is
    // monotonic. When the batch ran delegation in-session, it fills the first
    // slice; otherwise the bar starts at 0 and covers only submissions.
    private var submissionProgress: (Double, String) {
        let delegationWeight = 0.3

        switch status {
        case .authorizing:
            let p: Double
            switch store.delegationProofStatus {
            case .generating(let pp): p = pp
            case .complete: p = 1.0
            default: p = 0
            }
            return (p * delegationWeight, String(localizable: .coinVoteConfirmSubmissionProgressAuthorizing))

        case let .submitting(currentIndex, totalCount, _):
            let offset = store.delegationProofStatus == .complete ? delegationWeight : 0.0
            let fraction = Double(currentIndex + 1) / Double(max(totalCount, 1))
            let overall = min(1.0, offset + fraction * (1.0 - offset))
            return (overall, String(localizable: .coinVoteConfirmSubmissionProgressSubmittingVotes))

        case .authorizationFailed:
            return (0, String(localizable: .coinVoteConfirmSubmissionProgressAuthorizing))

        case let .submissionFailed(_, submittedCount, totalCount):
            let fraction = Double(submittedCount) / Double(max(totalCount, 1))
            let overall = min(1.0, delegationWeight + fraction * (1.0 - delegationWeight))
            return (overall, String(localizable: .coinVoteConfirmSubmissionProgressSubmittingVotes))

        default:
            return (0, "")
        }
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private func bottomSection() -> some View {
        switch status {
        case .idle:
            ZashiButton(
                store.isKeystoneUser
                    ? String(localizable: .coinVoteConfirmSubmissionConfirmWithKeystone)
                    : String(localizable: .coinVoteCommonConfirm)
            ) {
                store.send(.submitAllDrafts)
            }

        case .authorizing, .submitting, .authorizationFailed, .submissionFailed:
            // Progress card stays on screen underneath the error sheet, which
            // is driven by the authorizationFailed / submissionFailed bindings
            // and owns the retry/cancel affordance.
            let (progress, title) = submissionProgress
            VStack(spacing: Design.Spacing._lg) {
                VStack(alignment: .leading, spacing: Design.Spacing._lg) {
                    Text(title)
                        .zFont(.semiBold, size: 15, style: Design.Text.primary)

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
                }
                .padding(Design.Spacing._2xl)
                .background(Design.Surfaces.bgSecondary.color(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius._xl))

                ZashiButton(title) {}
                    .disabled(true)
            }

        case .completed:
            ZashiButton(String(localizable: .coinVoteCommonDone)) {
                store.send(.doneTapped)
            }
        }
    }
}
