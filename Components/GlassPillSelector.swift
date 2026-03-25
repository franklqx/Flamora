//
//  GlassPillSelector.swift
//  Flamora app
//
//  Reusable glass-style pill selector (e.g. time range: 1W / 1M / 3M / YTD / ALL)
//
//  Uses onTapGesture instead of Button to avoid SwiftUI Button gesture
//  conflicts inside ScrollView (buttons can become unresponsive when
//  UIScrollView's gesture system competes with SwiftUI's Button recognizer).
//

import SwiftUI

struct GlassPillSelector<T: Hashable>: View {
    let items: [T]
    @Binding var selected: T
    let label: (T) -> String

    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(label(item))
                    .font(.smallLabel)
                    .foregroundColor(item == selected ? .white : AppColors.textTertiary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background {
                        if item == selected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 8).fill(AppColors.glassPillFill))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.glassPillStroke, lineWidth: 0.5))
                                .shadow(color: AppColors.cardTopHighlight, radius: 4)
                                .matchedGeometryEffect(id: "pill", in: pillNS)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selected = item
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
