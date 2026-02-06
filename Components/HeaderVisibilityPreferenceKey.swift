//
//  HeaderVisibilityPreferenceKey.swift
//  Flamora app
//

import SwiftUI

struct HeaderVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
