//
//  KeystoneHandlerTestKey.swift
//  Zashi
//
//  Created by Lukáš Korba on 2024-11-20.
//

import ComposableArchitecture
import XCTestDynamicOverlay
@preconcurrency import KeystoneSDK

extension KeystoneHandlerClient: TestDependencyKey {
    static let testValue = Self(
        decodeQR: unimplemented("\(Self.self).decodeQR", placeholder: nil),
        resetQRDecoder: unimplemented("\(Self.self).resetQRDecoder")
    )
}

extension KeystoneHandlerClient {
    static let noOp = Self(
        decodeQR: { _ in nil },
        resetQRDecoder: { }
    )
}
