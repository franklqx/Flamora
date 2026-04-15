//
//  NoDelayScrollView.swift
//  Flamora app
//
//  Wraps SwiftUI ScrollView and disables delaysContentTouches on the
//  underlying UIScrollView so that buttons (e.g. GlassPillSelector) respond
//  immediately without waiting for the scroll-gesture disambiguation delay.
//
//  Key design decisions:
//  • Fix runs in updateUIView (not makeUIView) — the UIView is in the
//    hierarchy by then, so superview chain is valid.
//  • We walk ALL ancestors and fix every UIScrollView, not just the first.
//    In Xcode Previews the first UIScrollView up the chain can be a preview
//    container; stopping there would leave our ScrollView unfixed.
//

import SwiftUI
import UIKit

struct NoDelayScrollView<Content: View>: View {
    let showsIndicators: Bool
    @ViewBuilder let content: () -> Content

    init(showsIndicators: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            content()
                .background(ScrollViewTouchFixer())
        }
    }
}

// MARK: - Internal fixer

private struct ScrollViewTouchFixer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        var ancestor = uiView.superview
        while let v = ancestor {
            if let sv = v as? UIScrollView {
                sv.delaysContentTouches = false
            }
            ancestor = v.superview
        }
    }
}
