//
//  ContentView.swift
//  Flamora app
//
//  Created by Frank Li on 2/3/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
