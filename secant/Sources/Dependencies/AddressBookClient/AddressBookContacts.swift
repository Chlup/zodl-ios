//
//  AddressBookContacts.swift
//  Zashi
//
//  Created by Lukáš Korba on 09-30-2024.
//

import Foundation
import ComposableArchitecture

struct AddressBookContacts: Equatable, Codable {
    enum Constants {
        static let version = 2
    }
    
    let lastUpdated: Date
    let version: Int
    var contacts: IdentifiedArrayOf<Contact>
}

extension AddressBookContacts {
    static let empty = AddressBookContacts(lastUpdated: .distantPast, version: Constants.version, contacts: [])
}
