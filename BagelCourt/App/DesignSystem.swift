import SwiftUI

// MARK: - Colours
// Exact token values from the spec — do not change these to semantic colours.

extension Color {
    static let bcBg           = Color(bcHex: "#0E0E0E")
    static let bcCard         = Color(bcHex: "#131313")
    static let bcCardActive   = Color(bcHex: "#201F1F")
    static let bcAccent       = Color(bcHex: "#CDFF67")
    static let bcAccentDim    = Color(bcHex: "#CDFF67").opacity(0.10)
    static let bcMuted        = Color(bcHex: "#ADAAAA")
    static let bcBorder       = Color(bcHex: "#262626")
    static let bcStepper      = Color(bcHex: "#2C2C2C")
    static let bcCustomBorder = Color(bcHex: "#CDFF67").opacity(0.20)

    /// Initialise from a CSS-style hex string, e.g. "#CDFF67" or "CDFF67".
    init(bcHex hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        var raw: UInt64 = 0
        Scanner(string: str).scanHexInt64(&raw)
        let r = Double((raw >> 16) & 0xFF) / 255
        let g = Double((raw >>  8) & 0xFF) / 255
        let b = Double( raw        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Typography modifiers
// All body text is black-weight, uppercase, and widely tracked.

struct WordmarkModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 20, weight: .black)).tracking(2.0)
            .textCase(.uppercase).foregroundStyle(Color.bcAccent)
    }
}

struct StepLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 10, weight: .bold)).tracking(2.0)
            .textCase(.uppercase).foregroundStyle(Color.bcMuted)
    }
}

struct CardLabelModifier: ViewModifier {
    var accent: Bool
    func body(content: Content) -> some View {
        content.font(.system(size: 10, weight: .bold)).tracking(1.0)
            .textCase(.uppercase).foregroundStyle(accent ? Color.bcAccent : Color.bcMuted)
    }
}

struct PlayerNameModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 24, weight: .black)).tracking(-0.5)
            .textCase(.uppercase).foregroundStyle(Color.white)
    }
}

struct OptionTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 14, weight: .black))
            .textCase(.uppercase).foregroundStyle(Color.white)
    }
}

struct OptionSubtitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 10, weight: .medium))
            .textCase(.uppercase).foregroundStyle(Color.bcMuted)
    }
}

struct StepperLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 12, weight: .black)).tracking(1.2)
            .textCase(.uppercase).foregroundStyle(Color.white)
    }
}

struct SummaryBarModifier: ViewModifier {
    var accent: Bool
    func body(content: Content) -> some View {
        content.font(.system(size: 10, weight: .black)).tracking(3.0)
            .textCase(.uppercase).foregroundStyle(accent ? Color.bcAccent : Color.white)
    }
}

struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 18, weight: .black)).tracking(1.8)
            .textCase(.uppercase).foregroundStyle(Color.black)
    }
}

struct ScoreBigModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 64, weight: .black, design: .rounded))
            .foregroundStyle(Color.white)
    }
}

extension View {
    func wordmarkStyle() -> some View  { modifier(WordmarkModifier()) }
    func stepLabelStyle() -> some View { modifier(StepLabelModifier()) }
    func cardLabelStyle(accent: Bool = false) -> some View { modifier(CardLabelModifier(accent: accent)) }
    func playerNameStyle() -> some View { modifier(PlayerNameModifier()) }
    func optionTitleStyle() -> some View { modifier(OptionTitleModifier()) }
    func optionSubtitleStyle() -> some View { modifier(OptionSubtitleModifier()) }
    func stepperLabelStyle() -> some View { modifier(StepperLabelModifier()) }
    func summaryBarStyle(accent: Bool = false) -> some View { modifier(SummaryBarModifier(accent: accent)) }
    func primaryButtonStyle() -> some View { modifier(PrimaryButtonModifier()) }
    func scoreBigStyle() -> some View { modifier(ScoreBigModifier()) }
}

// MARK: - Corner radii (spec values)

enum BCRadius {
    static let card: CGFloat     = 8
    static let button: CGFloat   = 4
    static let stepper: CGFloat  = 2
    static let vsPill: CGFloat   = 12
}

// MARK: - Layout constants

enum BCLayout {
    static let horizontalMargin: CGFloat = 24
    static let stepSpacing: CGFloat      = 48
    static let intraStepSpacing: CGFloat = 16
}
