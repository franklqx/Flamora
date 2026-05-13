//
//  ChartInteractionLayer.swift
//  Meridian
//
//  UIViewRepresentable gesture layer for stock-style chart scrubbing.
//
//  Uses UILongPressGestureRecognizer (0.3s) so that quick taps pass through
//  to SwiftUI Buttons (e.g. GlassPillSelector) and the UIScrollView's own
//  pan gesture. Only after a sustained press does scrubbing activate.
//

import SwiftUI
import UIKit

// MARK: - UIViewRepresentable

struct ChartInteractionLayer: UIViewRepresentable {

    /// Called continuously while the user scrubs the chart.
    /// `x` = horizontal position in the chart's own coordinate space.
    /// `width` = total chart width (use to convert x → data index).
    var onDrag: (_ x: CGFloat, _ width: CGFloat) -> Void

    /// Called when the finger lifts or the gesture is cancelled.
    var onRelease: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrag: onDrag, onRelease: onRelease)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let g = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleGesture(_:))
        )
        g.minimumPressDuration    = 0.3   // match the "long-press 0.3s" UX spec
        g.allowableMovement       = .greatestFiniteMagnitude  // allow drag after recognition
        g.cancelsTouchesInView    = false  // don't cancel Button touches
        g.delaysTouchesBegan      = false
        g.delaysTouchesEnded      = false
        g.delegate                = context.coordinator
        view.addGestureRecognizer(g)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDrag = onDrag
        context.coordinator.onRelease = onRelease
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDrag: (_ x: CGFloat, _ width: CGFloat) -> Void
        var onRelease: () -> Void

        init(onDrag: @escaping (CGFloat, CGFloat) -> Void,
             onRelease: @escaping () -> Void) {
            self.onDrag = onDrag
            self.onRelease = onRelease
        }

        @objc func handleGesture(_ g: UILongPressGestureRecognizer) {
            guard let view = g.view else { return }
            let loc = g.location(in: view)

            switch g.state {
            case .began, .changed:
                onDrag(loc.x, view.bounds.width)
            case .ended, .cancelled:
                onRelease()
            default:
                break
            }
        }

        // Allow scroll view pan to work alongside this gesture
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()

        ChartInteractionLayer(
            onDrag: { _, _ in },
            onRelease: {}
        )
        .frame(height: 200)
        .background(AppColors.chartBlue.opacity(0.2))
    }
}
#endif
