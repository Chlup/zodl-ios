import SwiftUI
import ComposableArchitecture

struct VotingView: View {
    let store: StoreOf<Voting>

    public init(store: StoreOf<Voting>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            let screen = store.screenStack.last ?? .pollsList
            screenView(for: screen)
                .id(screenId(screen))
                .animation(.easeInOut(duration: 0.3), value: store.selectedProposal?.id)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            store.send(.initialize)
        }
        .sheet(
            store: store.scope(state: \.$keystoneScan, action: \.keystoneScan)
        ) { scanStore in
            ScanView(store: scanStore, popoverRatio: 1.075)
        }
        .votingSheet(
            isPresented: pollClosedBinding,
            title: "Poll Closed",
            message: "The voting period closed. Your responses cannot be saved.",
            primary: .init(title: "View results", style: .primary) {
                store.send(.viewPollClosedResults)
            },
            secondary: .init(title: "Close", style: .secondary) {
                store.send(.dismissPollClosedSheet)
            }
        )
    }

    private var pollClosedBinding: Binding<Bool> {
        Binding(
            get: { store.showPollClosedSheet },
            set: { newValue in
                if !newValue { store.send(.dismissPollClosedSheet) }
            }
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func screenId(_ screen: Voting.State.Screen) -> String {
        switch screen {
        case .howToVote: return "howToVote"
        case .loading: return "loading"
        case .noRounds: return "noRounds"
        case .pollsList: return "pollsList"
        case .delegationSigning: return "delegationSigning"
        case .proposalList: return "proposalList"
        case .proposalDetail(let id): return "detail-\(id)"
        case .complete: return "complete"
        case .ineligible: return "ineligible"
        case .tallying: return "tallying"
        case .results: return "results"
        case .reviewVotes: return "reviewVotes"
        case .confirmSubmission: return "confirmSubmission"
        case .error: return "error"
        case .configError: return "configError"
        case .walletSyncing: return "walletSyncing"
        }
    }

    @ViewBuilder
    private func screenView( // swiftlint:disable:this cyclomatic_complexity
        for screen: Voting.State.Screen
    ) -> some View {
        switch screen {
        case .howToVote:
            HowToVoteView(store: store)
        case .loading:
            ProgressView()
        case .noRounds:
            NoRoundsView(store: store)
        case .pollsList:
            PollsListView(store: store)
        case .delegationSigning:
            DelegationSigningView(store: store)
        case .proposalList:
            ProposalListView(store: store, mode: .voting)
        case .reviewVotes:
            ProposalListView(store: store, mode: .review)
        case .confirmSubmission:
            ConfirmSubmissionView(store: store)
        case .proposalDetail:
            if let proposal = store.selectedProposal {
                ProposalDetailView(store: store, proposal: proposal)
                    .id(proposal.id)
                    .transition(.push(from: .trailing))
            }
        case .complete:
            VoteCompletionView(store: store)
        case .ineligible:
            IneligibleView(store: store)
        case .tallying:
            TallyingView(store: store)
        case .results:
            ResultsView(store: store)
        case .error(let message):
            VotingErrorView(store: store, errorMessage: message)
        case .configError(let message):
            VotingConfigErrorView(store: store, errorMessage: message)
        case .walletSyncing:
            WalletSyncingView(store: store)
        }
    }
}

// MARK: - No Rounds

struct NoRoundsView: View {
    let store: StoreOf<Voting>

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Voting Rounds")
                .font(.headline)
            Text("There are no voting rounds available right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .navigationTitle("Governance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { store.send(.dismissFlow) } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}

// MARK: - Placeholders

extension Voting.State {
    static let initial = Voting.State()
}

extension StoreOf<Voting> {
    static let placeholder = StoreOf<Voting>(
        initialState: .initial
    ) {
        Voting()
    }
}

#Preview {
    NavigationStack {
        VotingView(store: .placeholder)
    }
}
