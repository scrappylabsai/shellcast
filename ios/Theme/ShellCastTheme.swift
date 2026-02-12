import SwiftUI

/// WCAG 2.2 AA compliant ScrappyLabs dark theme.
/// All colors reference Asset Catalog color sets.
enum ShellCastTheme {
    // MARK: - Core Colors

    static let background = Color("BackgroundColor")        // #0d0d14
    static let surface = Color("SurfaceColor")              // #1a1a2e
    static let text = Color("TextColor")                    // #f0f0f5
    static let textMuted = Color("TextMutedColor")          // #8a8aa0
    static let accent = Color("AccentColor")                // #ff6b35
    static let accent2 = Color("Accent2Color")              // #00d4ff
    static let error = Color("ErrorColor")                  // #ff4757
    static let success = Color("SuccessColor")              // #2ed573
    static let border = Color("BorderColor")                // #4a4a6a
    static let borderInteractive = Color("BorderInteractiveColor") // #6e6e82

    // MARK: - Typography

    static let titleFont: Font = .title2.weight(.bold)
    static let headlineFont: Font = .headline
    static let bodyFont: Font = .body
    static let captionFont: Font = .caption
    static let monoFont: Font = .system(.body, design: .monospaced)

    // MARK: - Spacing

    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
}
