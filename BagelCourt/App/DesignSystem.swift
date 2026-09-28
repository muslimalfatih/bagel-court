import SwiftUI
import CoreText

// MARK: - Colours
// tourney.social palette, dark only. Gold carries one meaning: it's tappable, or it won.
// Views use these tokens, never raw colours.

extension Color {
    static let bcBg            = Color(bcHex: "#0D0D0F")   // page
    static let bcCard          = Color(bcHex: "#151517")   // surfaces
    static let bcCardActive    = Color(bcHex: "#1E1E21")   // fills inside cards: selected states, inputs
    static let bcAccent        = Color(bcHex: "#D4A94E")   // gold
    static let bcAccentPressed = Color(bcHex: "#E0BD6F")
    static let bcMuted         = Color(bcHex: "#8F8C84")
    static let bcBorder        = Color(bcHex: "#2B2B2F")   // hairlines
    static let bcStepper       = Color(bcHex: "#1E1E21")   // control surfaces, incl. disabled buttons
    static let bcText         = Color(bcHex: "#ECE9E2")   // warm ivory
    static let bcOnAccent      = Color(bcHex: "#121006")   // text and icons on gold

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

// MARK: - Fonts
// Instrument Serif: the logo, titles and big names. Sentence case, never tracked capitals; one weight.
// Geist Mono: labels (uppercase, tracked, medium) and data (scores, times, counts).
// Everything else uses the system font.

enum BCMonoWeight: String { case regular = "Regular", medium = "Medium", bold = "Bold" }

extension Font {
    static func bcSerif(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: size)
    }

    static func bcMono(_ size: CGFloat, _ weight: BCMonoWeight = .regular) -> Font {
        .custom("GeistMono-\(weight.rawValue)", size: size)
    }
}

enum BCFonts {
    /// Registers the bundled fonts (BagelCourt/Fonts). The generated Info.plist can't list UIAppFonts,
    /// so this runs once at launch.
    static func register() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Text styles

struct WordmarkModifier: ViewModifier {   // the "BagelCourt" logo
    func body(content: Content) -> some View {
        content.font(.bcSerif(26, italic: true)).foregroundStyle(Color.bcText)
    }
}

struct TitleModifier: ViewModifier {      // screen titles and headlines
    func body(content: Content) -> some View {
        content.font(.bcSerif(30)).foregroundStyle(Color.bcText)
    }
}

/// Labels: eyebrows, pills, column headers. Mono, uppercase, tracked 0.08 em.
struct LabelModifier: ViewModifier {
    var color: Color
    var size: CGFloat = 11
    func body(content: Content) -> some View {
        content.font(.bcMono(size, .medium)).tracking(size * 0.08)
            .textCase(.uppercase).foregroundStyle(color)
    }
}

struct PlayerNameModifier: ViewModifier { // big names: point buttons and the winner
    func body(content: Content) -> some View {
        content.font(.bcSerif(40)).foregroundStyle(Color.bcText)
    }
}

struct OptionTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bcText)
    }
}

extension View {
    func wordmarkStyle() -> some View  { modifier(WordmarkModifier()) }
    func titleStyle() -> some View     { modifier(TitleModifier()) }
    func stepLabelStyle() -> some View { modifier(LabelModifier(color: .bcMuted)) }
    func cardLabelStyle(accent: Bool = false) -> some View { modifier(LabelModifier(color: accent ? .bcAccent : .bcMuted)) }
    func playerNameStyle() -> some View { modifier(PlayerNameModifier()) }
    func optionTitleStyle() -> some View { modifier(OptionTitleModifier()) }
    func optionSubtitleStyle() -> some View { modifier(LabelModifier(color: .bcMuted, size: 10)) }
    /// Third tier under an option's title and subtitle: a plain sentence, quieter than the capitals above it.
    func optionDetailStyle() -> some View { font(.caption2).foregroundStyle(Color.bcMuted) }
    func summaryBarStyle(accent: Bool = false) -> some View { modifier(LabelModifier(color: accent ? .bcAccent : .bcMuted)) }
}

// MARK: - Buttons
// Both styles react on touch-down with a colour change, not an animation.

/// The screen's main action: a gold pill, lighter while pressed, flat and muted when disabled.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bcMono(15, .medium)).tracking(1.2).textCase(.uppercase)
            .foregroundStyle(isEnabled ? Color.bcOnAccent : Color.bcMuted)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isEnabled ? (configuration.isPressed ? Color.bcAccentPressed : Color.bcAccent) : Color.bcStepper,
                        in: Capsule())
    }
}

/// Secondary actions: an outlined pill.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bcMono(12, .medium)).tracking(1.0).textCase(.uppercase)
            .foregroundStyle(isEnabled ? Color.bcText : Color.bcMuted.opacity(0.5))
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(configuration.isPressed ? Color.bcCardActive : .clear, in: Capsule())
            .overlay(Capsule().stroke(Color.bcBorder, lineWidth: 1))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle   { static var bcPrimary: Self { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var bcSecondary: Self { .init() } }

// MARK: - Corner radii

enum BCRadius {
    static let card: CGFloat    = 18   // cards
    static let control: CGFloat = 12   // inputs, steppers and other small controls; pills use Capsule
}

extension View {
    /// A card: surface fill, card corners and a hairline border.
    func cardSurface() -> some View {
        background(Color.bcCard)
            .clipShape(RoundedRectangle(cornerRadius: BCRadius.card))
            .overlay(RoundedRectangle(cornerRadius: BCRadius.card).stroke(Color.bcBorder, lineWidth: 1))
    }
}

// MARK: - Layout constants

enum BCLayout {
    static let horizontalMargin: CGFloat = 24
    static let stepSpacing: CGFloat      = 48
    static let intraStepSpacing: CGFloat = 16
}

// MARK: - Motion
// Critically damped springs: no overshoot, interruptible, and they keep their velocity when retargeted.

extension Animation {
    static let bcQuick  = Animation.smooth(duration: 0.2)   // selections and value changes
    static let bcSmooth = Animation.smooth(duration: 0.3)   // things appearing, leaving or resizing
}

extension AnyTransition {
    /// Content that appears in place: fades in while settling 8 pt; fade only under Reduce Motion.
    static func bcReveal(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -8))
    }
}
