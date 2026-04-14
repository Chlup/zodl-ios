import SwiftUI
import ComposableArchitecture

struct DelegationSigningView: View {
    @Environment(\.colorScheme)
    var colorScheme
    @Dependency(\.sdkSynchronizer)
    var sdkSynchronizer

    let store: StoreOf<Voting>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        keystoneDeviceCard()
                            .padding(.top, 40)

                        qrCodeSection()
                            .padding(.top, 32)

                        instructionText()
                            .padding(.top, 32)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                actionButtons()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .screenTitle("Confirmation")
        .zashiBack {
            store.send(.delegationRejected)
        }
        .navigationBarBackButtonHidden()
        .alert(
            store: store.scope(
                state: \.$skipBundlesAlert,
                action: \.skipBundlesAlert
            )
        )
    }

    // MARK: - Keystone Device Card

    @ViewBuilder
    private func keystoneDeviceCard() -> some View {
        HStack(spacing: 0) {
            Asset.Assets.Partners.keystoneLogo.image
                .resizable()
                .frame(width: 24, height: 24)
                .padding(8)
                .background {
                    Circle()
                        .fill(Design.Surfaces.bgAlt.color(colorScheme))
                }
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 0) {
                Text(localizable: .accountsKeystone)
                    .zFont(.semiBold, size: 16, style: Design.Text.primary)

                if let address = store.selectedWalletAccount?.unifiedAddress {
                    Text(address)
                        .zFont(fontFamily: .robotoMono, size: 12, style: Design.Text.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(localizable: .keystoneSignWithHardware)
                .zFont(.medium, size: 12, style: Design.Utility.HyperBlue._700)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: Design.Radius._2xl)
                        .fill(Design.Utility.HyperBlue._50.color(colorScheme))
                        .background {
                            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                                .stroke(Design.Utility.HyperBlue._200.color(colorScheme))
                        }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Design.Radius._2xl)
                .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
        }
    }

    // MARK: - QR Code Section

    @ViewBuilder
    private func qrCodeSection() -> some View {
        switch store.keystoneSigningStatus {
        case .idle, .preparingRequest:
            VStack {
                ProgressView()
                    .padding(.bottom, 8)
                Text("Building delegation request...")
                    .zFont(.medium, size: 13, style: Design.Text.tertiary)
            }
            .frame(width: 216, height: 216)
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius._xl)
                    .fill(Asset.Colors.ZDesign.Base.bone.color)
                    .background {
                        RoundedRectangle(cornerRadius: Design.Radius._xl)
                            .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
                    }
            }

        case .awaitingSignature:
            if let pczt = store.pendingUnsignedDelegationPczt,
               let encoder = sdkSynchronizer.urEncoderForPCZT(pczt) {
                AnimatedQRCode(urEncoder: encoder, size: 250)
                    .frame(width: 216, height: 216)
                    .padding(24)
                    .background {
                        RoundedRectangle(cornerRadius: Design.Radius._xl)
                            .fill(Asset.Colors.ZDesign.Base.bone.color)
                            .background {
                                RoundedRectangle(cornerRadius: Design.Radius._xl)
                                    .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
                            }
                    }
            } else {
                Text("QR encoding failed. Tap Cancel and try again.")
                    .zFont(size: 13, style: Design.Text.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(24)
            }

        case .parsingSignature:
            VStack {
                ProgressView()
                    .padding(.bottom, 8)
                Text("Processing signature...")
                    .zFont(.medium, size: 13, style: Design.Text.tertiary)
            }
            .frame(width: 216, height: 216)
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: Design.Radius._xl)
                    .fill(Asset.Colors.ZDesign.Base.bone.color)
                    .background {
                        RoundedRectangle(cornerRadius: Design.Radius._xl)
                            .stroke(Design.Surfaces.strokeSecondary.color(colorScheme))
                    }
            }

        case .failed(let error):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundStyle(Design.Utility.ErrorRed._500.color(colorScheme))
                Text(error)
                    .zFont(size: 13, style: Design.Text.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 216)
            .padding(24)
        }
    }

    // MARK: - Instruction Text

    @ViewBuilder
    private func instructionText() -> some View {
        VStack(spacing: 4) {
            if store.bundleCount > 1 {
                Text("Bundle \(store.currentKeystoneBundleIndex + 1) of \(store.bundleCount)")
                    .zFont(.semiBold, size: 14, style: Design.Text.primary)
                    .padding(.bottom, 4)
            }

            Text(localizable: .keystoneSignWithTitle)
                .zFont(.medium, size: 16, style: Design.Text.primary)

            // swiftlint:disable:next line_length
            Text("After you have signed with Keystone, tap on the Scan Signature button below.")
                .zFont(size: 14, style: Design.Text.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons() -> some View {
        VStack(spacing: 8) {
            switch store.keystoneSigningStatus {
            case .idle, .preparingRequest:
                ZashiButton("Cancel", type: .ghost) {
                    store.send(.delegationRejected)
                }
                ZashiButton("Scan Signature") { }
                    .disabled(true)
                    .opacity(0.5)

            case .awaitingSignature:
                ZashiButton("Cancel", type: .ghost) {
                    store.send(.delegationRejected)
                }
                ZashiButton("Scan Signature") {
                    store.send(.openKeystoneSignatureScan)
                }

            case .parsingSignature:
                ZashiButton("Processing...") { }
                    .disabled(true)
                    .opacity(0.5)

            case .failed:
                ZashiButton("Cancel", type: .ghost) {
                    store.send(.delegationRejected)
                }
                ZashiButton("Retry") {
                    store.send(.retryKeystoneSigning)
                }
            }

            // Skip remaining bundles — only shown after at least one bundle is signed
            if !store.keystoneBundleSignatures.isEmpty && store.bundleCount > 1 {
                skipRemainingBundlesButton()
            }
        }
    }
}

// MARK: - Skip Remaining Bundles

extension DelegationSigningView {
    @ViewBuilder
    func skipRemainingBundlesButton() -> some View {
        let signed = store.keystoneBundleSignatures.count
        let remaining = Int(store.bundleCount) - signed

        ZashiButton("Skip Remaining \(remaining) Bundle\(remaining == 1 ? "" : "s")", type: .ghost) {
            store.send(.skipRemainingKeystoneBundles)
        }
    }
}
