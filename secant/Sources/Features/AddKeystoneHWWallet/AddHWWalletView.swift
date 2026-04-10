//
//  AddKeystoneHWWalletView.swift
//  Zashi
//
//  Created by Lukáš Korba on 2024-11-26.
//

import SwiftUI
import ComposableArchitecture

struct AddKeystoneHWWalletView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Perception.Bindable var store: StoreOf<AddKeystoneHWWallet>
    
    init(store: StoreOf<AddKeystoneHWWallet>) {
        self.store = store
    }
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Asset.Assets.Partners.keystoneTitleLogo.image
                            .resizable()
                            .frame(width: 193, height: 32)
                            .padding(.top, 16)

                        Text(localizable: .keystoneConnect)
                            .zFont(.semiBold, size: 24, style: Design.Text.primary)
                            .padding(.top, 24)
                        
                        Text(localizable: .keystoneAddHWWalletScan)
                            .zFont(size: 14, style: Design.Text.tertiary)
                            .lineSpacing(1.5)
                            .padding(.top, 8)

                        #if DEBUG
                        Button {
                            store.send(.viewTutorialTapped)
                        } label: {
                            Text(localizable: .keystoneAddHWWalletTutorial)
                                .font(.custom(FontFamily.Inter.semiBold.name, size: 14))
                                .foregroundColor(Design.Utility.HyperBlue._700.color(colorScheme))
                                .underline()
                                .padding(.top, 4)
                        }
                        #endif

                        Text(localizable: .keystoneAddHWWalletHowTo)
                            .zFont(.semiBold, size: 18, style: Design.Text.primary)
                            .padding(.top, 24)
                        
                        InfoRow(
                            icon: Asset.Assets.Icons.lockUnlocked.image,
                            title: String(localizable: .keystoneAddHWWalletStep1)
                        )
                        .padding(.top, 16)
                        
                        InfoRow(
                            icon: Asset.Assets.Icons.dotsMenu.image,
                            title: String(localizable: .keystoneAddHWWalletStep2)
                        )
                        .padding(.top, 16)

                        InfoRow(
                            icon: Asset.Assets.Icons.connectWallet.image,
                            title: String(localizable: .keystoneAddHWWalletStep3)
                        )
                        .padding(.top, 16)

                        InfoRow(
                            icon: Asset.Assets.Icons.zashiLogoSqBold.image,
                            title: String(localizable: .keystoneAddHWWalletStep4)
                        )
                        .padding(.top, 16)
                    }
                }
                .padding(.vertical, 1)
                
                Spacer()
                
                ZashiButton(String(localizable: .keystoneAddHWWalletReadyToScan)) {
                    store.send(.readyToScanTapped)
                }
                .padding(.vertical, 24)
            }
            .screenHorizontalPadding()
            .onAppear { store.send(.onAppear) }
            .zashiBack() {
                store.send(.backToHomeTapped)
            }
            .sheet(isPresented: $store.isInAppBrowserOn) {
                if let url = URL(string: store.inAppBrowserURL) {
                    InAppBrowserView(url: url)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .applyScreenBackground()
    }
}

// MARK: Placeholders

extension AddKeystoneHWWallet.State {
    static let initial = AddKeystoneHWWallet.State()
}

extension AddKeystoneHWWallet {
    @MainActor static let initial = StoreOf<AddKeystoneHWWallet>(
        initialState: .initial
    ) {
        AddKeystoneHWWallet()
    }
}

#Preview {
    NavigationView {
        AddKeystoneHWWalletView(store: AddKeystoneHWWallet.initial)
    }
}
