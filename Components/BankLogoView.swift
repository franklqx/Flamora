//
//  BankLogoView.swift
//  Meridian
//
//  Render a Plaid institution logo (base64 PNG) with three fallback tiers:
//    1. Real logo (institutionLogoBase64) → decoded image
//    2. Brand color (institutionPrimaryColor) → filled circle, first letter of institution
//    3. SF Symbol fallback (passed in) → tinted by `fallbackColor`
//

import SwiftUI
import UIKit

struct BankLogoView: View {
    let logoBase64: String?
    let primaryColorHex: String?
    let institutionName: String?
    let fallbackSymbol: String
    let fallbackColor: Color
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            if let image = decodedImage {
                Circle()
                    .fill(AppColors.shellBg1)
                    .frame(width: size, height: size)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.7, height: size * 0.7)
                    .clipShape(Circle())
            } else if let brandColor = brandColor, let initial = initial {
                Circle()
                    .fill(brandColor)
                    .frame(width: size, height: size)
                Text(initial)
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.shellBg1)
            } else {
                Circle()
                    .fill(fallbackColor.opacity(0.15))
                    .frame(width: size, height: size)
                Image(systemName: fallbackSymbol)
                    .font(.footnoteSemibold)
                    .foregroundStyle(fallbackColor)
            }
        }
    }

    private var decodedImage: UIImage? {
        guard let logoBase64, !logoBase64.isEmpty else { return nil }
        // Plaid returns raw base64 without a data:image prefix.
        let cleaned = logoBase64.contains(",")
            ? String(logoBase64.split(separator: ",").last ?? "")
            : logoBase64
        guard let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }

    private var brandColor: Color? {
        guard let primaryColorHex else { return nil }
        let cleaned = primaryColorHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        // Color(hex:) silently falls back to black on bad input, so gate it on a sane length.
        guard [3, 6, 8].contains(cleaned.count) else { return nil }
        return Color(hex: primaryColorHex)
    }

    private var initial: String? {
        guard let name = institutionName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }
        return String(name.prefix(1)).uppercased()
    }
}

