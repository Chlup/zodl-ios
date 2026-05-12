import SwiftUI
import ComposableArchitecture

struct WalletSyncingView: View {
    @Environment(\.colorScheme)
    var colorScheme

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VotingBlockingBackdrop(store: store)
                .votingBlockingSheet(
                    isActive: { store.currentScreen == .walletSyncing },
                    onExit: { store.send(.dismissFlow) }
                ) { dismiss in
                    sheetContent(dismiss: dismiss)
                }
        }
    }

    // MARK: - Sheet

    @ViewBuilder
    private func sheetContent(dismiss: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            sheetIcon()
                .padding(.top, 16)
                .padding(.bottom, 16)

            Text(localizable: .coinVoteWalletSyncingTitle)
                .zFont(.semiBold, size: 22, style: Design.Text.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text(localizable: .coinVoteWalletSyncingSubtitle)
                .zFont(.regular, size: 15, style: Design.Text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            syncProgressCard()
                .padding(.bottom, 12)

            infoCard()
                .padding(.bottom, 24)

            ZashiButton(String(localizable: .coinVoteCommonClose)) {
                dismiss()
            }
            .padding(.bottom, Design.Spacing.sheetBottomSpace)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sheetIcon() -> some View {
        ZStack {
            Circle()
                .fill(Design.Utility.WarningYellow._500.color(colorScheme).opacity(0.1))
                .frame(width: 48, height: 48)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Design.Utility.WarningYellow._500.color(colorScheme).opacity(0.8))
        }
    }

    // MARK: - Sync Progress Card

    @ViewBuilder
    private func syncProgressCard() -> some View {
        let snapshotHeight = store.activeSession?.snapshotHeight ?? 0
        let scannedHeight = store.walletScannedHeight

        VStack(alignment: .leading, spacing: 12) {
            detailRow(
                label: String(localizable: .coinVoteWalletSyncingDetailSyncedTo),
                value: String(localizable: .coinVoteCommonBlockNumber(formatted(scannedHeight)))
            )
            detailRow(
                label: String(localizable: .coinVoteWalletSyncingDetailSnapshotBlock),
                value: String(localizable: .coinVoteCommonBlockNumber(formatted(snapshotHeight)))
            )

            if snapshotHeight > 0 {
                Divider()

                let remaining = snapshotHeight > scannedHeight ? snapshotHeight - scannedHeight : 0
                detailRow(
                    label: String(localizable: .coinVoteWalletSyncingDetailBlocksRemaining),
                    value: formatted(remaining)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Design.Surfaces.bgPrimary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Info Card

    @ViewBuilder
    private func infoCard() -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(Design.Text.tertiary.color(colorScheme))

            Text(localizable: .coinVoteWalletSyncingInfo)
                .zFont(.regular, size: 14, style: Design.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Design.Text.secondary.color(colorScheme).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .zFont(.medium, size: 14, style: Design.Text.tertiary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Design.Text.primary.color(colorScheme))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatted(_ value: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
