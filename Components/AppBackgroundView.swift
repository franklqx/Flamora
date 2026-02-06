//
//  AppBackgroundView.swift
//  Flamora app
//

import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        Image("AppBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}

#Preview {
    AppBackgroundView()
}

