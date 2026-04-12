//
//  AddressBookInterface.swift
//  Zashi
//
//  Created by Lukáš Korba on 05-27-2024.
//

import ComposableArchitecture
@preconcurrency import ZcashLightClientKit

extension DependencyValues {
    var addressBook: AddressBookClient {
        get { self[AddressBookClient.self] }
        set { self[AddressBookClient.self] = newValue }
    }
}

@DependencyClient
struct AddressBookClient {
    let resetAccount: (Account) throws -> Void
    let allLocalContacts: (Account) throws -> (contacts: AddressBookContacts, remoteStoreResult: RemoteStoreResult)
    let syncContacts: (Account, AddressBookContacts?) async throws -> (contacts: AddressBookContacts, remoteStoreResult: RemoteStoreResult)
    let storeContact: (Account, Contact) throws -> (contacts: AddressBookContacts, remoteStoreResult: RemoteStoreResult)
    let deleteContact: (Account, Contact) throws -> (contacts: AddressBookContacts, remoteStoreResult: RemoteStoreResult)
}
