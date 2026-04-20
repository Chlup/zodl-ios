//
//  WalletLogger.swift
//  Zashi
//
//  Created by Lukáš Korba on 23.01.2023.
//

import Foundation
@preconcurrency import ZcashLightClientKit
import os

enum LoggerConstants {
    static let sdkLogs = "sdkLogs_default"
    static let tcaLogs = "tcaLogs"
    static let walletLogs = "walletLogs"
}

/// Thread-safe storage for the global wallet logger, guarded by an `OSAllocatedUnfairLock`.
///
/// `ZcashLightClientKit.Logger` is imported via `@preconcurrency` and isn't annotated
/// `Sendable`, but all access goes through the lock so the holder is thread-safe on its own.
private let walletLoggerStorage = OSAllocatedUnfairLock<ZcashLightClientKit.Logger?>(initialState: nil)

var walletLogger: ZcashLightClientKit.Logger? {
    get { walletLoggerStorage.withLock { $0 } }
    set { walletLoggerStorage.withLock { $0 = newValue } }
}

enum LoggerProxy {
    static func debug(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        walletLogger?.debug(message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        walletLogger?.info(message, file: file, function: function, line: line)
    }
    
    static func event(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        walletLogger?.event(message, file: file, function: function, line: line)
    }
    
    static func warn(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        walletLogger?.warn(message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        walletLogger?.error(message, file: file, function: function, line: line)
    }
}
