import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Display typeface (bundled Playfair Display, registered at runtime)

enum Typeface {
    static private(set) var displayName: String?

    static func register() {
        guard displayName == nil else { return }
        if let url = Bundle.main.url(forResource: "PlayfairDisplay", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        for candidate in ["Playfair Display", "PlayfairDisplay-Regular"] {
            #if canImport(UIKit)
            if UIFont(name: candidate, size: 12) != nil { displayName = candidate; break }
            #elseif canImport(AppKit)
            if NSFont(name: candidate, size: 12) != nil { displayName = candidate; break }
            #endif
        }
    }
}

extension Font {
    /// The bundled display serif, scaling with Dynamic Type. Falls back to the
    /// system serif if the custom font failed to register.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        if let name = Typeface.displayName {
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(size: size, weight: .semibold, design: .serif)
    }
}

// MARK: - Color tokens (light/dark, no asset catalog needed)

extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }

    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }

    static let bgCanvas       = Color(light: Color(hex: 0xFBF8F2), dark: Color(hex: 0x16140F))
    static let surfacePool    = Color(light: Color(hex: 0xF2ECE0), dark: Color(hex: 0x1E1B15))
    static let inkPrimary     = Color(light: Color(hex: 0x1F1B16), dark: Color(hex: 0xF2ECE0))
    static let inkBody        = Color(light: Color(hex: 0x3D3833), dark: Color(hex: 0xBEB7AD))
    static let inkSecondary   = Color(light: Color(hex: 0x8A8275), dark: Color(hex: 0x968C7C))
    static let inkTertiary    = Color(light: Color(hex: 0xB4AC9E), dark: Color(hex: 0x5E574B))
    static let hairline       = Color(light: Color(hex: 0xE9E3D8), dark: Color(hex: 0x2A261E))
    static let placeholderInk = Color(light: Color(hex: 0xB8B1A6), dark: Color(hex: 0x5C564E))
    static let accentInk      = Color(light: Color(hex: 0xB5733F), dark: Color(hex: 0xD08A52))
    static let accentPressed  = Color(light: Color(hex: 0x9E6234), dark: Color(hex: 0xBE7A45))
    /// The crowned hero's card — elevated via LIGHT, not shadow: crisp white over
    /// warm paper, a raised warm tone over near-black. Reads as lifted in both.
    static let cardElevated   = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x24201A))
}

// MARK: - Appearance preference (System / Light / Dark)

enum Appearance: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    var symbol: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    var next: Appearance {
        let all = Self.allCases
        return all[(all.firstIndex(of: self).map { $0 + 1 } ?? 0) % all.count]
    }
}

// MARK: - Spacing scale (8pt grid)

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 36
    static let pool: CGFloat = 32
}

// MARK: - Motion (one calm settle spring + a livelier completion bounce)

enum Motion {
    static let settle = Animation.spring(response: 0.40, dampingFraction: 0.85)
    static let complete = Animation.spring(response: 0.32, dampingFraction: 0.55)
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.50)
    /// The signature ambient re-rank: slow, high-damping, zero overshoot. This is
    /// the AI "thinking out loud" — fired only at safe idle moments, never under
    /// the cursor. Calmer and longer than `settle` so a re-sort reads as reasoning.
    static let ambient = Animation.spring(response: 0.62, dampingFraction: 0.90)
}

// MARK: - Gravity ramp (rank → pre-attentive type size + ink, one channel)

/// Maps a task's rank position within its day to a quantized type size and ink
/// tone — the single pre-attentive channel that encodes importance (Healey/Ware).
/// Quantized to fixed steps snapped to the grid so the column never jitters on a
/// re-rank. `flattened` compresses the ramp when the ranker isn't confident.
enum Gravity {
    /// On-deck / body rows for Today (rank 1 = just under the hero).
    static func today(rank: Int, flattened: Bool) -> (size: CGFloat, color: Color) {
        if flattened {
            switch rank {
            case 1, 2, 3: return (16, .inkBody)
            default: return (14, .inkSecondary)
            }
        }
        switch rank {
        case 1: return (18, .inkPrimary)
        case 2: return (16.5, .inkBody)
        case 3: return (15.5, .inkBody)
        case 4: return (14.5, .inkSecondary)
        default: return (14, .inkSecondary)   // floor — still clears 4.5:1
        }
    }

    /// Receding strata: later days are quieter so Today owns the screen.
    static func later(rank: Int) -> (size: CGFloat, color: Color) {
        switch rank {
        case 0, 1: return (15, .inkSecondary)
        default: return (14, .inkSecondary)
        }
    }
}

// MARK: - Date helpers

extension Date {
    /// "Today" / "Tomorrow" / weekday name.
    var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInTomorrow(self) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: self)
    }

    /// "Jun 21"
    var daySubLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}
