//
//  GradientButton.swift
//  Flamora app
//
//  Created by Frank Li on 2/2/26.
//

import SwiftUI

struct GradientButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.bodyRegular)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(28)
                .shadow(color: AppColors.gradientStart.opacity(0.4), radius: 16, y: 8)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AppColors.backgroundPrimary
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GradientButton(title: "Enter simulator") {
                print("Button tapped!")
            }
            
            GradientButton(title: "Launch simulation") {
                print("Launch tapped!")
            }
        }
        .padding()
    }
}
