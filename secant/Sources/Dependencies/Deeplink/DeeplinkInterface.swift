//
//  DeeplinkInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 11.11.2022.
//

import Foundation
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

extension DependencyValues {
    var deeplink: DeeplinkClient {
        get { self[DeeplinkClient.self] }
        set { self[DeeplinkClient.self] = newValue }
    }
}

@DependencyClient
struct DeeplinkClient {
    let resolveDeeplinkURL: (URL, NetworkType, DerivationToolClient) throws -> Deeplink.Destination
    
    init(resolveDeeplinkURL: @escaping (URL, NetworkType, DerivationToolClient) throws -> Deeplink.Destination) {
        self.resolveDeeplinkURL = resolveDeeplinkURL
    }
}
