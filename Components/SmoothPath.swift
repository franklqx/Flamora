//
//  SmoothPath.swift
//  Flamora app
//
//  Catmull-Rom spline interpolation for smooth chart curves
//

import SwiftUI

/// Converts an array of CGPoints into a smooth SwiftUI Path using Catmull-Rom spline.
/// - Parameters:
///   - points: The data points to connect
///   - tension: Controls curve tightness (0 = sharp, 1 = very smooth). Default 0.3
/// - Returns: A smooth Path through all points
func smoothPath(points: [CGPoint], tension: CGFloat = 0.3) -> Path {
    Path { path in
        guard points.count >= 2 else { return }

        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
            return
        }

        for i in 0 ..< points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]

            let cp1x = p1.x + (p2.x - p0.x) / 6 * tension * 3
            let cp1y = p1.y + (p2.y - p0.y) / 6 * tension * 3
            let cp2x = p2.x - (p3.x - p1.x) / 6 * tension * 3
            let cp2y = p2.y - (p3.y - p1.y) / 6 * tension * 3

            path.addCurve(
                to: p2,
                control1: CGPoint(x: cp1x, y: cp1y),
                control2: CGPoint(x: cp2x, y: cp2y)
            )
        }
    }
}

/// Creates a closed area path from smooth curve down to the bottom edge.
/// - Parameters:
///   - points: The data points
///   - bottomY: The Y coordinate of the bottom edge (typically geo.size.height)
///   - tension: Curve tightness
/// - Returns: A closed Path suitable for area fill
func smoothAreaPath(points: [CGPoint], bottomY: CGFloat, tension: CGFloat = 0.3) -> Path {
    Path { path in
        guard let first = points.first, let last = points.last else { return }

        // Start from bottom-left
        path.move(to: CGPoint(x: first.x, y: bottomY))
        path.addLine(to: first)

        // Draw smooth curve through all points
        if points.count == 2 {
            path.addLine(to: points[1])
        } else {
            for i in 0 ..< points.count - 1 {
                let p0 = points[max(i - 1, 0)]
                let p1 = points[i]
                let p2 = points[min(i + 1, points.count - 1)]
                let p3 = points[min(i + 2, points.count - 1)]

                let cp1x = p1.x + (p2.x - p0.x) / 6 * tension * 3
                let cp1y = p1.y + (p2.y - p0.y) / 6 * tension * 3
                let cp2x = p2.x - (p3.x - p1.x) / 6 * tension * 3
                let cp2y = p2.y - (p3.y - p1.y) / 6 * tension * 3

                path.addCurve(
                    to: p2,
                    control1: CGPoint(x: cp1x, y: cp1y),
                    control2: CGPoint(x: cp2x, y: cp2y)
                )
            }
        }

        // Close down to bottom-right
        path.addLine(to: CGPoint(x: last.x, y: bottomY))
        path.closeSubpath()
    }
}
