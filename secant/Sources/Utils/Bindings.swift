@preconcurrency import SwiftUI
import CasePaths

/// taken largely from: https://github.com/pointfreeco/episode-code-samples/blob/main/0167-navigation-pt8/SwiftUINavigation/SwiftUINavigation/SwiftUIHelpers.swift
extension Binding {
    func isPresent<Wrapped>() -> Binding<Bool>
    where Value == Wrapped? {
        nonisolated(unsafe) let selfRef = self
        return .init(
            get: { selfRef.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    selfRef.wrappedValue = nil
                }
            }
        )
    }

    func isPresent<Enum, Case>(_ casePath: AnyCasePath<Enum, Case>) -> Binding<Bool>
    where Value == Enum? {
        nonisolated(unsafe) let selfRef = self
        return Binding<Bool>(
            get: {
                if let wrappedValue = selfRef.wrappedValue, casePath.extract(from: wrappedValue) != nil {
                    return true
                } else {
                    return false
                }
            },
            set: { isPresented in
                if !isPresented {
                    selfRef.wrappedValue = nil
                }
            }
        )
    }

    func `case`<Enum, Case>(_ casePath: AnyCasePath<Enum, Case>) -> Binding<Case?>
    where Value == Enum? {
        nonisolated(unsafe) let selfRef = self
        return Binding<Case?>(
            get: {
                guard
                    let wrappedValue = selfRef.wrappedValue,
                    let `case` = casePath.extract(from: wrappedValue)
                else { return nil }
                return `case`
            },

            set: { `case` in
                if let `case` = `case` {
                    selfRef.wrappedValue = casePath.embed(`case`)
                } else {
                    selfRef.wrappedValue = nil
                }
            }
        )
    }

    func didSet(_ callback: @escaping (Value) -> Void) -> Self {
        nonisolated(unsafe) let selfRef = self
        nonisolated(unsafe) let callback = callback
        return .init(
            get: { selfRef.wrappedValue },
            set: {
                selfRef.wrappedValue = $0
                callback($0)
            }
        )
    }

    init?(unwrap binding: Binding<Value?>) {
        guard let wrappedValue = binding.wrappedValue
        else { return nil }

        nonisolated(unsafe) let unsafeBinding = binding
        nonisolated(unsafe) let capturedValue = wrappedValue
        self.init(
            get: { capturedValue },
            set: { unsafeBinding.wrappedValue = $0 }
        )
    }

    func map<T>(extract: @escaping (Value) -> T, embed: @escaping (T) -> Value) -> Binding<T> {
        nonisolated(unsafe) let selfRef = self
        nonisolated(unsafe) let extract = extract
        nonisolated(unsafe) let embed = embed
        return Binding<T>(
            get: { extract(selfRef.wrappedValue) },
            set: { selfRef.wrappedValue = embed($0) }
        )
    }

    func compactMap<T>(extract: @escaping (Value) -> T, embed: @escaping (T) -> Value?) -> Binding<T> {
        nonisolated(unsafe) let selfRef = self
        nonisolated(unsafe) let extract = extract
        nonisolated(unsafe) let embed = embed
        return Binding<T>(
            get: { extract(selfRef.wrappedValue) },
            set: {
                guard let value = embed($0) else {
                    return
                }
                selfRef.wrappedValue = value
            }
        )
    }
}
