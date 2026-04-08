//
//  WalletBirthdayView.swift
//  Zashi
//
//  Created by Lukáš Korba on 03-31-2025.
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct WalletBirthdayView: View {
    @Perception.Bindable var store: StoreOf<WalletBirthday>
    
    @State var keyboardVisible: Bool = false
    @FocusState var isBirthdayFocused

    public init(store: StoreOf<WalletBirthday>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                if store.isKeystoneFlow {
                    Asset.Assets.Partners.keystoneTitleLogo.image
                        .resizable()
                        .frame(width: 193, height: 32)
                        .padding(.top, 16)
                }
                
                Text(localizable: .importWalletBirthdayTitle)
                    .zFont(.semiBold, size: 24, style: Design.Text.primary)
                    .padding(.top, 40)
                    .padding(.bottom, 8)

                // TODO: loc
                Text(
                    localizable:
                        store.isKeystoneFlow
//                    ? .addHWWalletBirthdayInfo
                    ? .restoreWalletBirthdayInfo
                    : .restoreWalletBirthdayInfo
                )
                .zFont(size: 14, style: Design.Text.primary)
                .padding(.bottom, 32)
                
                ZashiTextField(
                    text: $store.birthday,
                    placeholder: String(localizable: .restoreWalletBirthdayPlaceholder),
                    title: String(localizable: .restoreWalletBirthdayTitle)
                )
                .padding(.bottom, 6)
                .keyboardType(.numberPad)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isBirthdayFocused)
                
                Text(localizable: .restoreWalletBirthdayFieldInfo)
                    .zFont(size: 12, style: Design.Text.tertiary)
                
                Spacer()
                
                if !store.isKeystoneFlow {
                    ZashiButton(
                        String(localizable: .restoreWalletBirthdayEstimate),
                        type: .ghost
                    ) {
                        store.send(.estimateHeightTapped)
                    }
                    .padding(.bottom, 12)
                }
                    // TODO: Loc
//                    ZashiButton(String(localizable: .importWalletButtonRestoreWallet)) {
                ZashiButton(store.isKeystoneFlow ? "L10n.Keystone.AddHWWallet.connect" : "L10n.ImportWallet.Button.restoreWallet") {
//                ZashiButton(store.isKeystoneFlow ? String(localizable: .keystoneAddHWWalletConnect) : String(localizable: .importWalletButtonRestoreWallet)) {
                  store.send(.restoreTapped)
                }
                .disabled(!store.isValidBirthday)
                .padding(.bottom, keyboardVisible ? 48 : 24)
            }
            .zashiBack()
        }
        .onAppear { isBirthdayFocused = true }
        .navigationBarTitleDisplayMode(.inline)
        .trackKeyboardVisibility($keyboardVisible)
        .navigationBarItems(
            trailing:
                Button {
                    store.send(.helpSheetRequested)
                } label: {
                    Asset.Assets.Icons.help.image
                        .zImage(size: 24, style: Design.Text.primary)
                        .padding(Design.Spacing.navBarButtonPadding)
                }
        )
        .screenHorizontalPadding()
        .applyScreenBackground()
        // TODO: Loc
//        .screenTitle(String(localizable: .importWalletButtonRestoreWallet))
        .screenTitle(store.isKeystoneFlow ? "L10n.Keystone.connect" : "L10n.ImportWallet.Button.restoreWallet")
//        .screenTitle(store.isKeystoneFlow ? "" : String(localizable: .importWalletButtonRestoreWallet))
        .overlay {
            if keyboardVisible {
                VStack(spacing: 0) {
                    Spacer()
                    
                    Asset.Colors.primary.color
                        .frame(height: 1)
                        .opacity(0.1)
                    
                    HStack(alignment: .center) {
                        Spacer()
                        
                        Button {
                            isBirthdayFocused = false
                        } label: {
                            Text(localizable: .generalDone)
//                            Text(String(localizable: .generalDone).uppercased())
                                .zFont(.regular, size: 14, style: Design.Text.primary)
                        }
                        .applyScreenBackground()
                        .padding(.horizontal, 20)
                        .frame(height: keyboardVisible ? 38 : 0)
                        .frame(maxWidth: .infinity)
                        .opacity(keyboardVisible ? 1 : 0)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    WalletBirthdayView(store: WalletBirthday.initial)
}

// MARK: - Store

extension WalletBirthday {
    public static var initial = StoreOf<WalletBirthday>(
        initialState: .initial
    ) {
        WalletBirthday()
    }
}

// MARK: - Placeholders

extension WalletBirthday.State {
    public static let initial = WalletBirthday.State()
}
