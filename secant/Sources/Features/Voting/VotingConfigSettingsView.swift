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

    @Dependency(\.pasteboard) private var pasteboard

    private let copyTapFeedback = UIImpactFeedbackGenerator(style: .light)

    @State private var expandedDefaultChain = false
    @State private var expandedChainIds: Set<UUID> = []

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 24) {
                            header
                            introSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 32, leading: 0, bottom: 24, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        defaultChainOption
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(store.chains) { chain in
                            customChainRow(chain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        expandedChainIds.remove(chain.id)
                                        store.send(.customChainDeleteTapped(chain.id))
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Delete")
                                                .zFont(.medium, size: 12, style: Design.Surfaces.bgPrimary)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background {
                                            RoundedRectangle(cornerRadius: Design.Radius._xl)
                                                .fill(Color.black)
                                        }
                                    }
                                    .tint(Color.clear)
                                    .accessibilityLabel(String(localized: "Delete \(chain.name)"))
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
            .onChange(of: store.selection) { newSelection in
                if case .bundled = newSelection, !store.showAddChainFields {
                    expandedChainIds.removeAll()
                }
            }
            .onChange(of: store.showAddChainFields) { showing in
                if !showing {
                    if case .bundled = store.selection {
                        expandedChainIds.removeAll()
                    }
                }
            }
        }
    }

    /// Expanded custom-chain details (checksum, copy fields) only when a custom chain is selected or Add is active.
    private var allowsCustomChainDisclosure: Bool {
        switch store.selection {
        case .custom:
            return true
        case .bundled:
            return store.showAddChainFields
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Color.clear
                .frame(width: 32, height: 32)

            Text("SELECT CHAIN")
                .zFont(.semiBold, size: 22, style: Design.Text.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button {
                store.send(.dismissTapped)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .zForegroundColor(Design.Text.tertiary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(String(localized: "Cancel"))
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Poll Data Source")
                .zFont(.semiBold, size: 16, style: Design.Text.primary)

            Text("Select or enter a chain URL to fetch poll data from")
                .zFont(size: 13, style: Design.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var defaultChainOption: some View {
        let isSelected = store.selection == .bundled
        let pair = VotingChainDisplayURL.defaultBundled

        return HStack(alignment: .top, spacing: 12) {
            Button {
                store.send(.bundledTapped)
            } label: {
                selectionIndicator(isSelected: isSelected)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityLabel(String(localized: "Default chain"))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Default")
                        .zFont(.semiBold, size: 16, style: Design.Text.primary)

                    if isCurrentBundled {
                        currentPill
                    }

                    Spacer(minLength: 0)

                    Button {
                        expandedDefaultChain.toggle()
                    } label: {
                        disclosureChevron(expanded: expandedDefaultChain)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        expandedDefaultChain
                            ? String(localized: "Hide full chain URL")
                            : String(localized: "Show full chain URL")
                    )
                }

                Text(pair.compact)
                    .zFont(size: 12, style: Design.Text.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if expandedDefaultChain {
                    expandedDefaultExtras(fullChainURL: pair.full)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius._xl)
                .fill(Design.Surfaces.bgSecondary.color(colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: Design.Radius._xl)
                        .stroke(
                            isSelected
                                ? Asset.Colors.primary.color
                                : Design.Surfaces.strokeSecondary.color(colorScheme),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
        }
        .accessibilityElement(children: .contain)
    }

    private func customChainRow(_ chain: CustomChainEntry) -> some View {
        let isSelected = isCustomSelected(chain.id)
        let isExpanded = allowsCustomChainDisclosure && expandedChainIds.contains(chain.id)
        let pair = VotingChainDisplayURL.compactAndFull(for: chain.url)

        return HStack(alignment: .top, spacing: 12) {
            Button {
                store.send(.customChainSelected(chain.id))
            } label: {
                selectionIndicator(isSelected: isSelected)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Select \(chain.name)"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Button {
                        expandedChainIds.remove(chain.id)
                        store.send(.editChainTapped(chain.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(chain.name)
                                    .zFont(.semiBold, size: 16, style: Design.Text.primary)
                                    .multilineTextAlignment(.leading)

                                if isCurrentChain(chain) {
                                    currentPill
                                }

                                Spacer(minLength: 0)
                                // Reserve space so the disclosure control remains tappable, not this button.
                                Color.clear
                                    .frame(width: 36, height: 32)
                            }

                            Text(pair.compact)
                                .zFont(size: 12, style: Design.Text.tertiary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Edit \(chain.name)"))
                    .accessibilityHint(String(localized: "Opens fields to change the name and URL."))

                    Button {
                        toggleExpandedChain(chain.id)
                    } label: {
                        disclosureChevron(expanded: isExpanded)
                    }
                    .buttonStyle(.plain)
                    .disabled(!allowsCustomChainDisclosure)
                    .opacity(allowsCustomChainDisclosure ? 1 : 0.35)
                    .padding(.top, 10)
                    .padding(.trailing, 4)
                    .accessibilityLabel(
                        isExpanded
                            ? String(localized: "Hide full chain URL")
                            : String(localized: "Show full chain URL")
                    )
                }

                if isExpanded {
                    expandedCustomChainExtras(chain: chain, fullURL: pair.full)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius._xl)
                .fill(Design.Surfaces.bgSecondary.color(colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: Design.Radius._xl)
                        .stroke(
                            isSelected
                                ? Asset.Colors.primary.color
                                : Design.Surfaces.strokeSecondary.color(colorScheme),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
        }
    }

    private func disclosureChevron(expanded: Bool) -> some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Design.Text.tertiary.color(colorScheme))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }

    private func toggleExpandedChain(_ id: UUID) {
        guard allowsCustomChainDisclosure else { return }
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

    /// Read-only row styled like a text field; tap copies `value`.
    private func tapToCopyInputShape(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom(FontFamily.Inter.medium.name, size: 14))
                .zForegroundColor(Design.Inputs.Filled.label)

            Button {
                copyToPasteboard(value)
            } label: {
                Text(value)
                    .font(.custom(FontFamily.Inter.regular.name, size: 14))
                    .foregroundStyle(Design.Text.primary.color(colorScheme))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius._lg)
                            .fill(Design.Inputs.Default.bg.color(colorScheme))
                            .overlay {
                                RoundedRectangle(cornerRadius: Design.Radius._lg)
                                    .stroke(Design.Inputs.Default.bg.color(colorScheme))
                            }
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityHint(String(localized: "Tap to copy to clipboard."))
    }

    private func expandedDefaultExtras(fullChainURL: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .background(Design.Surfaces.strokeSecondary.color(colorScheme))

            tapToCopyInputShape(title: String(localized: "Name"), value: String(localized: "Default"))
            tapToCopyInputShape(title: String(localized: "Configuration URL"), value: fullChainURL)
        }
        .padding(.top, 4)
    }

    private func expandedCustomChainExtras(chain: CustomChainEntry, fullURL: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .background(Design.Surfaces.strokeSecondary.color(colorScheme))

            tapToCopyInputShape(title: String(localized: "Name"), value: chain.name)
            tapToCopyInputShape(title: String(localized: "Configuration URL"), value: fullURL)
        }
        .padding(.top, 4)
    }

    private var editChainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom chain")
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                Spacer()

                Button("Cancel") {
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

            Text("Pin is optional. If present, it is checked against the response body's SHA-256 hash.")
                .zFont(size: 13, style: Design.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if !store.showAddChainFields {
                Button {
                    store.send(.addCustomChainButtonTapped)
                } label: {
                    Text("+ Add custom chain")
                        .zFont(.medium, size: 16, style: Design.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Design.Surfaces.bgTertiary.color(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Design.Radius._xl))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            ZashiButton(saveTitle) {
                store.send(.saveTapped)
            }
            .disabled(saveDisabled)
        }
        .animation(.easeInOut(duration: 0.2), value: store.showAddChainFields)
    }

    private var addCustomChainSheet: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Custom URL")
                        .zFont(.semiBold, size: 20, style: Design.Text.primary)
                        .lineSpacing(2)

                    Text("Add a poll source that isn't listed by default. You'll need a valid chain URL from the provider hosting the poll.")
                        .zFont(size: 14, style: Design.Text.tertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    customChainSheetTextField(
                        text: pendingNewChainNameBinding,
                        placeholder: String(localized: "Enter title....")
                    )
                    .textInputAutocapitalization(.words)

                    customChainSheetTextField(
                        text: pendingNewChainURLBinding,
                        placeholder: String(localized: "Enter url...")
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
        text: Binding<String>,
        placeholder: String
    ) -> some View {
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

    private var currentPill: some View {
        Text("Current")
            .zFont(.semiBold, size: 12, style: Design.Surfaces.bgPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(Asset.Colors.primary.color)
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

    private var isCurrentBundled: Bool {
        store.override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isCurrentChain(_ chain: CustomChainEntry) -> Bool {
        let o = store.override.trimmingCharacters(in: .whitespacesAndNewlines)
        return !o.isEmpty && o == chain.url
    }

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
        isValidating ? String(localized: "Validating...") : String(localized: "Save")
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
