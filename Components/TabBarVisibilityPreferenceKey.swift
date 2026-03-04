//
//  TabBarVisibilityPreferenceKey.swift
//  Flamora app
//

import SwiftUI

struct TabBarVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
