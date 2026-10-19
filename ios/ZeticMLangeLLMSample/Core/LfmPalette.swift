import SwiftUI
import UIKit

enum LfmPalette {
    static let accent = adaptive(0x25465F, 0xDCE8F1)
    static let onAccent = adaptive(0xFFFFFF, 0x173247)
    static let surface = adaptive(0xFFFFFF, 0x193442)
    static let background = adaptive(0xF7F8FB, 0x102632)
    static let surfaceSubtle = adaptive(0xEFF2F8, 0x263F50)
    static let divider = adaptive(0xBBC6CD, 0x365264)
    static let ink = adaptive(0x25465F, 0xE8EFF6)
    static let secondary = adaptive(0x5C6F7F, 0xB6C9D8)
    static let error = adaptive(0xD42D02, 0xFFB1B4)
    static let highlight = Color(red: 1, green: 223 / 255, blue: 0)

    static func title(_ size: CGFloat = 32) -> Font {
        .custom("BouyguesSpeak-Bold", size: size, relativeTo: .title)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .custom("BouyguesRead-Regular", size: size, relativeTo: .body)
    }

    static func medium(_ size: CGFloat = 16) -> Font {
        .custom("BouyguesRead-Medium", size: size, relativeTo: .body)
    }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

/// Shared native geometry. Spacing follows the Trilogy 8pt grid, with 4pt small increments.
enum LfmLayout {
    static let screen: CGFloat = 16
    static let actionHeight: CGFloat = 48
    static let controlRadius: CGFloat = 8
    static let bubbleRadius: CGFloat = 16
}
