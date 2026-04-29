import SwiftUI
import ComposableArchitecture

struct VoteCompletionView: View {
    @Environment(\.colorScheme) var colorScheme
    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Design.Utility.SuccessGreen._500.color(colorScheme))

                    Text(localizable: .coinVoteCompletionTitle)
                        .zFont(.semiBold, size: 22, style: Design.Text.primary)

                    Text(
                        localizable: .coinVoteCompletionSubtitle(
                            store.votingWeightZECString,
                            String(store.totalProposals)
                        )
                    )
                        .zFont(.regular, size: 15, style: Design.Text.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    ZashiButton(String(localizable: .coinVoteCommonDone), type: .primary) {
                        store.send(.doneTapped)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                }

                Spacer()
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}
