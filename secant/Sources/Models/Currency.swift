//
//  File.swift
//  
//
//  Created by Lukáš Korba on 22.05.2024.
//

import Foundation
@preconcurrency import ZcashLightClientKit

// Both will be defined in the SDK
enum CurrencyISO4217: String, CaseIterable, Equatable {
    case usd = "USD"
    
    var code: String {
        rawValue
    }
    
    var symbol: String {
        switch self {
        case .usd: return "$"
        }
    }
}

struct CurrencyConversion: Equatable {
    let iso4217: CurrencyISO4217
    let ratio: Double
    let timestamp: TimeInterval
    
    init(_ iso4217: CurrencyISO4217, ratio: Double, timestamp: TimeInterval) {
        self.iso4217 = iso4217
        self.ratio = (ratio * Double(1_000_000)).rounded(.down) / Double(1_000_000)
        self.timestamp = timestamp
    }
    
    func convert(_ zatoshi: Zatoshi) -> Double {
        ratio * (Double(zatoshi.amount) / Double(100_000_000))
    }
    
    func convert(_ zatoshi: Zatoshi) -> String {
        Decimal(convert(zatoshi)).formatted(.currency(code: iso4217.code))
    }
    
    func convert(_ currency: Double) -> Zatoshi {
        Zatoshi(Int64((currency / ratio) * Double(100_000_000)))
    }
}
