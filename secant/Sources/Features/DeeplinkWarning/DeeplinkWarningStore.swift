//
//  DeeplinkWarningStore.swift
//  Zashi
//
//  Created by Lukáš Korba on 06-12-2024.
//

import ComposableArchitecture

@Reducer
struct DeeplinkWarning {
    @ObservableState
    struct State: Equatable { }

    enum Action: Equatable {
        case rescanInZashi
    }

    init() { }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .rescanInZashi:
                return .none
            }
        }
    }
}
