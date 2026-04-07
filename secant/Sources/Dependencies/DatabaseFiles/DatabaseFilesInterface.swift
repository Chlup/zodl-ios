//
//  DatabaseFilesInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 11.11.2022.
//

import Foundation
import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

extension DependencyValues {
    var databaseFiles: DatabaseFilesClient {
        get { self[DatabaseFilesClient.self] }
        set { self[DatabaseFilesClient.self] = newValue }
    }
}

@DependencyClient
struct DatabaseFilesClient {
    let documentsDirectory: () -> URL
    let fsBlockDbRootFor: (ZcashNetwork) -> URL
    let cacheDbURLFor: (ZcashNetwork) -> URL
    var dataDbURLFor: (ZcashNetwork) -> URL = { _ in .emptyURL }
    let outputParamsURLFor: (ZcashNetwork) -> URL
    let pendingDbURLFor: (ZcashNetwork) -> URL
    let spendParamsURLFor: (ZcashNetwork) -> URL
    var toDirURLFor: (ZcashNetwork) -> URL = { _ in .emptyURL }
    var areDbFilesPresentFor: (ZcashNetwork) -> Bool = { _ in false }
}
