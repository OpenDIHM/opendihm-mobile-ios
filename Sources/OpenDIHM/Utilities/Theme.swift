/// Theme.swift
/// Branding guidelines implementation for OpenDIHM.

import SwiftUI

struct Theme {
    /// Deep Marine - Used for stability and wordmarks.
    static let primary = Color(hex: "#003B5C")
    
    /// Electric Cyan - Primary icon and action color.
    static let secondary = Color(hex: "#2B8CC4")
    
    /// Holographic Mist - Backgrounds and subtle UI.
    static let background = Color(hex: "#F0F7FA")
    
    /// Slate Grey - Secondary text.
    static let neutral = Color(hex: "#4A4A4A")
    
    /// Precision Blue - Custom gradient or highlight color derived from secondary.
    static let accent = Color(hex: "#E1F5FE")
    
    struct Typography {
        static func heading(size: CGFloat = 24) -> Font {
            .custom("Inter-Bold", size: size).bold()
        }
        
        static func body(size: CGFloat = 16) -> Font {
            .custom("Roboto-Regular", size: size)
        }
        
        static func mono(size: CGFloat = 14) -> Font {
            .custom("JetBrainsMono-Regular", size: size)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
