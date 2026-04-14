import SwiftUI
import ComposableArchitecture

struct HowToVoteView: View {
    @Environment(\.colorScheme) var colorScheme

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerIcons()
                            .padding(.top, 24)
                            .padding(.bottom, 24)

                        Text(store.isKeystoneUser ? "How to vote with Keystone" : "How to vote with Zodl")
                            .zFont(.semiBold, size: 24, style: Design.Text.primary)
                            .padding(.bottom, 8)

                        Text("Your ZEC gives you a voice. Shape the future of the Zcash network by voting on active proposals.")
                            .zFont(size: 15, style: Design.Text.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 32)

                        stepRow(
                            number: 1,
                            title: "Voting on Proposals",
                            // swiftlint:disable:next line_length
                            body: "Vote Support, Oppose, or Abstain on each question. You can skip questions and change your vote before submitting."
                        )
                        .padding(.bottom, 24)

                        stepRow(
                            number: 2,
                            title: "Authorize and Submit",
                            // swiftlint:disable:next line_length
                            body: "When you're ready, you'll confirm a small authorization transaction and submit your vote in one step. After submission, your vote cannot be changed."
                        )
                    }
                    .padding(.horizontal, 24)
                }

                infoCard()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                ZashiButton("Continue") {
                    store.send(.howToVoteContinueTapped)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .applyScreenBackground()
            .screenTitle("Coinholder Polling")
            .zashiBack { store.send(.dismissFlow) }
        }
    }

    // MARK: - Header Icons

    @ViewBuilder
    private func headerIcons() -> some View {
        VotingHeaderIcons(isKeystone: store.isKeystoneUser)
    }

    // MARK: - Numbered Step

    @ViewBuilder
    private func stepRow(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Design.Text.primary.color(colorScheme))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .zFont(.semiBold, size: 14, style: Design.Surfaces.bgPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                Text(body)
                    .zFont(size: 14, style: Design.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Info Card

    @ViewBuilder
    private func infoCard() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Asset.Assets.infoOutline.image
                .zImage(size: 16, style: Design.Text.tertiary)

            // swiftlint:disable:next line_length
            Text("Your balance at the snapshot time determines your voting weight. You don't need to move your funds anywhere.")
                .zFont(size: 12, style: Design.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Design.Surfaces.bgSecondary.color(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
