import SwiftUI
import ComposableArchitecture

private enum VotingChainDisplayURL {
    /// Display uses the canonical HTTPS URL (checksum query stripped). `full` is the stored string (pin preserved).
    static func compactAndFull(for raw: String) -> (compact: String, full: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pinned = try? PinnedConfigSource.parse(trimmed) else {
            return (trimmed, trimmed)
        }
        return (pinned.url.absoluteString, trimmed)
    }

    static var defaultBundled: (compact: String, full: String) {
        compactAndFull(for: StaticVotingConfig.bundledPinnedSource)
    }
}

struct VotingConfigSettingsView: View {
    let store: StoreOf<VotingConfigSettings>

    private static let shadowXxs = Color(red: 35.0 / 255.0, green: 31.0 / 255.0, blue: 32.0 / 255.0).opacity(0.04)

    @Dependency(\.pasteboard) private var pasteboard

    private let copyTapFeedback = UIImpactFeedbackGenerator(style: .light)

    @State private var expandedDefaultChain = false
    @State private var expandedChainIds: Set<UUID> = []

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                header
                    .padding(.vertical, 12)

                List {
                    Section {
                        introSection
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 24, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        defaultChainOption
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(store.chains) { chain in
                            customChainRow(chain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        expandedChainIds.remove(chain.id)
                                        store.send(.customChainDeleteTapped(chain.id))
                                    } label: {
                                        Label(String(localized: "Delete"), systemImage: "trash.fill")
                                    }
                                    .tint(.red)
                                    .accessibilityLabel(String(localized: "Delete \(chain.name)"))

                                    Button {
                                        expandedChainIds.remove(chain.id)
                                        store.send(.editChainTapped(chain.id))
                                    } label: {
                                        Label(String(localized: "Edit"), systemImage: "pencil")
                                    }
                                    .tint(Design.Text.tertiary.color(colorScheme))
                                    .accessibilityLabel(String(localized: "Edit \(chain.name)"))
                                }
                        }

                        if store.editingChainId != nil {
                            editChainSection
                                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        Color.clear
                            .frame(height: 24)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .applyScreenBackground()
            .zashiSheet(isPresented: addCustomChainSheetBinding) {
                addCustomChainSheet
            }
            .onAppear {
                expandedDefaultChain = false
                expandedChainIds.removeAll()
                store.send(.onAppear)
            }
        }
    }

    private var header: some View {
        ZStack {
            Text(String(localized: "SELECT CHAIN"))
                .zFont(.semiBold, size: 16, style: Design.Text.primary)
                .textCase(.uppercase)
                .tracking(-0.176)

            HStack {
                Button {
                    store.send(.dismissTapped)
                } label: {
                    Asset.Assets.Icons.arrowNarrowLeft.image
                        .zImage(size: 20, style: Design.Text.primary)
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: Design.Radius._md)
                                .fill(Design.Btns.Ghost.bg.color(colorScheme))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Back"))

                Spacer()

                Button {
                    store.send(.addCustomChainButtonTapped)
                } label: {
                    Asset.Assets.Icons.plus.image
                        .zImage(size: 20, style: Design.Text.primary)
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: Design.Radius._md)
                                .fill(Design.Btns.Ghost.bg.color(colorScheme))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Add custom chain"))
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Poll Data Source"))
                .zFont(.semiBold, size: 24, style: Design.Text.primary)
                .tracking(-0.384)

            Text(String(localized: "Select or enter a chain URL to fetch poll data from"))
                .zFont(size: 14, style: Design.Text.tertiary)
                .tracking(-0.084)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var defaultChainOption: some View {
        let isSelected = store.selection == .bundled
        let pair = VotingChainDisplayURL.defaultBundled

        return chainCard(isExpanded: expandedDefaultChain) {
            VStack(spacing: 20) {
                chainTopRow(
                    name: String(localized: "Default"),
                    isExpanded: expandedDefaultChain,
                    isSelected: isSelected,
                    onChevronTap: { expandedDefaultChain.toggle() },
                    onSelectTap: { store.send(.bundledTapped) },
                    selectAccessibilityLabel: String(localized: "Default chain"),
                    chevronAccessibilityLabel: expandedDefaultChain
                        ? String(localized: "Hide full chain URL")
                        : String(localized: "Show full chain URL")
                )

                if expandedDefaultChain {
                    chainExpandedContent(url: pair.full)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func customChainRow(_ chain: CustomChainEntry) -> some View {
        let isSelected = isCustomSelected(chain.id)
        let isExpanded = expandedChainIds.contains(chain.id)
        let pair = VotingChainDisplayURL.compactAndFull(for: chain.url)

        return chainCard(isExpanded: isExpanded) {
            VStack(spacing: 20) {
                chainTopRow(
                    name: chain.name,
                    isExpanded: isExpanded,
                    isSelected: isSelected,
                    onChevronTap: { toggleExpandedChain(chain.id) },
                    onSelectTap: { store.send(.customChainSelected(chain.id)) },
                    selectAccessibilityLabel: String(localized: "Select \(chain.name)"),
                    chevronAccessibilityLabel: isExpanded
                        ? String(localized: "Hide full chain URL")
                        : String(localized: "Show full chain URL")
                )

                if isExpanded {
                    chainExpandedContent(url: pair.full)
                }
            }
        }
    }

    /// Card container shared by Default and custom chain rows.
    /// Collapsed cards use radius-xl/12pt vertical; expanded cards use radius-2xl/16pt vertical (per Figma 739:5811 vs 739:5825).
    private func chainCard<Content: View>(
        isExpanded: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, isExpanded ? 16 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: isExpanded ? Design.Radius._2xl : Design.Radius._xl)
                    .fill(Design.Surfaces.bgSecondary.color(colorScheme))
            }
    }

    /// Top row: chevron toggles expansion (left); radio toggles selection (right).
    private func chainTopRow(
        name: String,
        isExpanded: Bool,
        isSelected: Bool,
        onChevronTap: @escaping () -> Void,
        onSelectTap: @escaping () -> Void,
        selectAccessibilityLabel: String,
        chevronAccessibilityLabel: String
    ) -> some View {
        HStack(spacing: 16) {
            Button(action: onChevronTap) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.Text.primary.color(colorScheme))
                        .frame(width: 20, height: 20)

                    Text(name)
                        .zFont(.medium, size: 16, style: Design.Text.primary)
                        .tracking(-0.256)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(chevronAccessibilityLabel)

            Button(action: onSelectTap) {
                selectionIndicator(isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectAccessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    /// Expanded payload: URL block (bgTertiary) + Copy Chain URL secondary button.
    private func chainExpandedContent(url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(url)
                .zFont(size: 12, style: Design.Text.tertiary)
                .tracking(-0.072)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: Design.Radius._xl)
                        .fill(Design.Surfaces.bgTertiary.color(colorScheme))
                }
                .accessibilityLabel(String(localized: "Chain URL"))
                .accessibilityValue(url)

            Button {
                copyToPasteboard(url)
            } label: {
                HStack(spacing: 4) {
                    Asset.Assets.copy.image
                        .zImage(size: 20, style: Design.Text.primary)

                    Text(String(localized: "Copy Chain URL"))
                        .zFont(.semiBold, size: 14, style: Design.Text.primary)
                        .tracking(-0.224)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    RoundedRectangle(cornerRadius: Design.Radius._xl)
                        .fill(Design.Btns.Secondary.bg.color(colorScheme))
                        .overlay {
                            RoundedRectangle(cornerRadius: Design.Radius._xl)
                                .stroke(Design.Btns.Secondary.border.color(colorScheme))
                        }
                        .shadow(color: Self.shadowXxs, radius: 0.5, x: 0, y: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Copy Chain URL"))
        }
    }

    private func toggleExpandedChain(_ id: UUID) {
        if expandedChainIds.contains(id) {
            expandedChainIds.remove(id)
        } else {
            expandedChainIds.insert(id)
        }
    }

    private func copyToPasteboard(_ string: String) {
        pasteboard.setString(string.redacted)
        copyTapFeedback.prepare()
        copyTapFeedback.impactOccurred()
    }

    private var editChainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Custom chain"))
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                Spacer()

                Button(String(localized: "Cancel")) {
                    store.send(.cancelChainEditTapped)
                }
                .zFont(.medium, size: 14, style: Design.Text.tertiary)
            }

            ZashiTextField(
                text: editChainNameBinding,
                placeholder: String(localized: "Name"),
                title: String(localized: "Name"),
                error: nil
            )

            ZashiTextField(
                text: editChainURLBinding,
                placeholder: String(localized: "Enter URL"),
                title: String(localized: "URL"),
                error: validationError
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Text(String(localized: "Pin is optional. If present, it is checked against the response body's SHA-256 hash."))
                .zFont(size: 13, style: Design.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomBar: some View {
        ZashiButton(saveTitle) {
            store.send(.saveTapped)
        }
        .disabled(saveDisabled)
    }

    private var addCustomChainSheet: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Add Custom URL"))
                        .zFont(.semiBold, size: 20, style: Design.Text.primary)
                        .lineSpacing(2)

                    Text(String(localized: "Manually add a poll source using its chain URL."))
                        .zFont(size: 14, style: Design.Text.tertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 20) {
                    customChainSheetTextField(
                        title: String(localized: "Title"),
                        text: pendingNewChainNameBinding,
                        placeholder: String(localized: "Enter....")
                    )
                    .textInputAutocapitalization(.words)

                    customChainSheetTextField(
                        title: String(localized: "URL"),
                        text: pendingNewChainURLBinding,
                        placeholder: String(localized: "Enter...")
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    if let validationError {
                        Text(validationError)
                            .font(.custom(FontFamily.Inter.regular.name, size: 14))
                            .foregroundColor(Design.Inputs.ErrorFilled.hint.color(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(spacing: 12) {
                ZashiButton(String(localized: "Cancel"), type: .secondary) {
                    store.send(.addCustomChainButtonTapped)
                }

                ZashiButton(addSourceTitle) {
                    store.send(.saveTapped)
                }
                .disabled(saveDisabled)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func customChainSheetTextField(
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom(FontFamily.Inter.medium.name, size: 14))
                .foregroundColor(Design.Text.primary.color(colorScheme))

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .font(.custom(FontFamily.Inter.regular.name, size: 16))
                    .foregroundColor(Design.Text.tertiary.color(colorScheme))
            )
            .font(.custom(FontFamily.Inter.regular.name, size: 16))
            .foregroundColor(Design.Text.primary.color(colorScheme))
            .lineLimit(1)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius._lg)
                    .fill(Design.Inputs.Default.bg.color(colorScheme))
            }
        }
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected
                        ? Asset.Colors.primary.color
                        : Design.Text.quaternary.color(colorScheme),
                    lineWidth: 1.5
                )
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(Asset.Colors.primary.color)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var pendingNewChainNameBinding: Binding<String> {
        Binding(
            get: { store.pendingNewChainName },
            set: { store.send(.pendingNewChainNameChanged($0)) }
        )
    }

    private var pendingNewChainURLBinding: Binding<String> {
        Binding(
            get: { store.pendingNewChainURL },
            set: { store.send(.pendingNewChainURLChanged($0)) }
        )
    }

    private var editChainNameBinding: Binding<String> {
        Binding(
            get: { store.editChainName },
            set: { store.send(.editChainNameChanged($0)) }
        )
    }

    private var editChainURLBinding: Binding<String> {
        Binding(
            get: { store.editChainURL },
            set: { store.send(.editChainURLChanged($0)) }
        )
    }

    private var addCustomChainSheetBinding: Binding<Bool> {
        Binding(
            get: { store.showAddChainFields },
            set: { isPresented in
                if !isPresented, store.showAddChainFields {
                    store.send(.addCustomChainButtonTapped)
                }
            }
        )
    }

    @Environment(\.colorScheme)
    private var colorScheme

    private func isCustomSelected(_ id: UUID) -> Bool {
        if case .custom(let sid) = store.selection {
            return sid == id
        }
        return false
    }

    private var validationError: String? {
        if case .error(let message) = store.validationStatus {
            return message
        }
        return nil
    }

    private var saveDisabled: Bool {
        if isValidating {
            return true
        }
        if store.editingChainId != nil {
            return store.editChainURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if store.showAddChainFields {
            return store.pendingNewChainURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private var saveTitle: String {
        isValidating ? String(localized: "Validating...") : String(localized: "Save changes")
    }

    private var addSourceTitle: String {
        isValidating ? String(localized: "Validating...") : String(localized: "Add source")
    }

    private var isValidating: Bool {
        store.validationStatus == .validating
    }
}

#Preview {
    VotingConfigSettingsView(
        store: Store(
            initialState: VotingConfigSettings.State()
        ) {
            VotingConfigSettings()
        }
    )
}
