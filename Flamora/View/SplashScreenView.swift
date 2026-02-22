//
//  SplashScreenView.swift
//  Flamora app
//
//  Created by Frank Li on 2/7/26.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            AppBackgroundView()

            Color.black.opacity(0.25)
                .ignoresSafeArea()

            Text("FLAMORA")
                .font(.custom("Montserrat-Bold", size: 38))
                .foregroundColor(.white)
                .tracking(2)
                .offset(y: -56)
        }
    }
}

#Preview {
    SplashScreenView()
}
