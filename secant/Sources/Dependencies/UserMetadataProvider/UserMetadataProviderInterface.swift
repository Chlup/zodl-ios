//
//  UserMetadataProviderInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 2025-01-28.
//

import Foundation
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

extension DependencyValues {
    var userMetadataProvider: UserMetadataProviderClient {
        get { self[UserMetadataProviderClient.self] }
        set { self[UserMetadataProviderClient.self] = newValue }
    }
}

@DependencyClient
struct UserMetadataProviderClient {
    // General
    let store: (Account) throws -> Void
    let load: (Account) throws -> Void
    let resetAccount: (Account) throws -> Void
    let reset: () throws -> Void

    // Bookmarking
    let isBookmarked: (String) -> Bool
    let toggleBookmarkFor: (String) -> Void
    
    // Annotations
    let annotationFor: (String) -> String?
    let addAnnotationFor: (String, String) -> Void
    let deleteAnnotationFor: (String) -> Void

    // Read
    let isRead: (String, TimeInterval?) -> Bool
    let readTx: (String) -> Void
    
    // Swap Id
    let allSwaps: () -> [UMSwapId]
    let isSwapTransaction: (String) -> Bool
    let swapDetailsForTransaction: (String) -> UMSwapId?
    let markTransactionAsSwapFor: (String, String, Int64, String, String, String, Bool, String, String) -> Void
    let update: (UMSwapId) -> Void
    
    // Last User SwapAssets
    let lastUsedAssetHistory: () -> [String]
    let addLastUsedSwapAsset: (String) -> Void
}
