import AppKit
import SwiftUI

/// openmy 深色终案（globals.css `.dark`，2026-07-14）：
/// 整窗一个黑 #0D0D0D，悬浮层 #1E1E1E，细线 #222222，
/// 零饱和度，文字 #ECECEC 起步，层级只靠明度台阶。
enum OpenMyChrome {
    static let canvasHex: UInt32 = 0x0D0D0D
    static let raiseHex: UInt32 = 0x1E1E1E
    static let hairHex: UInt32 = 0x222222
    static let fieldBorderHex: UInt32 = 0x2A2A2A
    static let inkHex: UInt32 = 0xECECEC
    static let mutedHex: UInt32 = 0x9B9B9B
    static let faintHex: UInt32 = 0x666666
    static let successHex: UInt32 = 0x41B98C
    static let warningHex: UInt32 = 0xD9A44C
    static let recHex: UInt32 = 0xE0607E

    static let canvas = Color(hex: canvasHex)
    static let raise = Color(hex: raiseHex)
    static let hair = Color(hex: hairHex)
    static let fieldBorder = Color(hex: fieldBorderHex)
    static let ink = Color(hex: inkHex)
    static let muted = Color(hex: mutedHex)
    static let faint = Color(hex: faintHex)
    static let success = Color(hex: successHex)
    static let warning = Color(hex: warningHex)
    static let rec = Color(hex: recHex)

    static let nsCanvas = NSColor(srgbRed: 13 / 255, green: 13 / 255, blue: 13 / 255, alpha: 1)

    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 10
    static let radiusLg: CGFloat = 12
    static let radiusXl: CGFloat = 16

    static func applyAppearance() {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    static func applyWindowChrome(_ window: NSWindow) {
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = nsCanvas
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = nsCanvas.cgColor
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
