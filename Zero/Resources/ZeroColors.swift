import SwiftUI

public extension Color {
    static let zero = ZeroColors()
}

extension Color {
    // Helper initializer for hex strings
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public extension ShapeStyle where Self == Color {
    static var zero: ZeroColors { Self.zero }
}

public struct ZeroColors {
    public let iconSuccessPrimary = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green900
    public let iconAccentPrimary = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green900
    public let iconAccentTertiary = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green800
    public let borderSuccessSubtle = Asset.Colors.blue11.swiftUIColor.opacity(0.5) // CompoundCoreColorTokens.green500
    public let bgAccentPressed = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green1100
    public let bgAccentHovered = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green1000
    public let bgAccentRest = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green900
    public let bgSuccessSubtle = Asset.Colors.blue11.swiftUIColor.opacity(0.2) // CompoundCoreColorTokens.green200
    public let textSuccessPrimary = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green900
    public let textActionAccent = Asset.Colors.blue11.swiftUIColor // CompoundCoreColorTokens.green900
    
//    public let bgCanvasDefault = Asset.Colors.zeroNewBackground.swiftUIColor
    public let bgCanvasDefault = Color.black
    
    public let _badgeTextSuccess = Asset.Colors.blue11.swiftUIColor // coreTokens.green1100
    public let _textOwnPill = Asset.Colors.blue11.swiftUIColor // coreTokens.green1100
    public let _bgAccentSelected = Asset.Colors.blue11.swiftUIColor.opacity(0.3) // coreTokens.green300
    public let _bgBubbleHighlighted = Asset.Colors.blue11.swiftUIColor.opacity(0.3) // coreTokens.green300
    public let _bgBadgeSuccess = Asset.Colors.blue11.swiftUIColor.opacity(0.3) // coreTokens.alphaGreen300
    public let _bgOwnPill = Asset.Colors.blue11.swiftUIColor.opacity(0.05)
    public let _bgOwnPillSecondary = Asset.Colors.zeroChatBubbleOutgoing.swiftUIColor.opacity(0.05)
    
    public let bgChatBubbleOutgoing = Asset.Colors.zeroChatBubbleOutgoing.swiftUIColor
    public let bgChatBubbleOutgoingSecondary = Color.init(hex: "#2B2B2B")
    public let bgChatBubbleIncoming = Asset.Colors.zeroChatBubbleIncoming.swiftUIColor
}
