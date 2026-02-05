//
//  Typography.swift
//  Fiamora app
//
//  Created by Frank Li 02/02/2026



import SwiftUI

struct AppTypography {
    // Font Sizes - 字号层级
    static let hero: CGFloat = 56
    static let display: CGFloat = 40
    static let h1: CGFloat = 32
    static let h2: CGFloat = 24
    static let h3: CGFloat = 20
    static let h4: CGFloat = 18
    static let body: CGFloat = 16
    static let bodySmall: CGFloat = 14
    static let caption: CGFloat = 12
    static let label: CGFloat = 10
}

// MARK: - Font Extension
extension Font {
    // Hero Styles
    static var hero: Font {
        .system(size: AppTypography.hero, weight: .black)
    }
    
    static var display: Font {
        .system(size: AppTypography.display, weight: .bold)
    }
    
    // Heading Styles
    static var h1: Font {
        .system(size: AppTypography.h1, weight: .bold)
    }
    
    static var h2: Font {
        .system(size: AppTypography.h2, weight: .bold)
    }
    
    static var h3: Font {
        .system(size: AppTypography.h3, weight: .semibold)
    }
    
    static var h4: Font {
        .system(size: AppTypography.h4, weight: .semibold)
    }
    
    // Body Styles
    static var bodyRegular: Font {
        .system(size: AppTypography.body, weight: .regular)
    }
    
    static var bodySmall: Font {
        .system(size: AppTypography.bodySmall, weight: .regular)
    }
    
    static var caption: Font {
        .system(size: AppTypography.caption, weight: .regular)
    }
    
    static var label: Font {
        .system(size: AppTypography.label, weight: .semibold)
    }
}
