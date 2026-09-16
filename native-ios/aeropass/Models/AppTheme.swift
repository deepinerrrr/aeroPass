import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case blue       = "经典蓝"
    case buJiaoLv   = "不焦绿"
    case jueJueZi   = "绝绝紫"
    case buBaiLan   = "不摆烂"
    case tangTaiZong = "糖太棕"
    case fangQingSong = "放青松"
    case faCaiHong  = "发财红"

    var id: String { rawValue }

    // 主色
    var color: Color {
        switch self {
        case .blue:        return Color(hex: "#4A7FCC")
        case .buJiaoLv:    return Color(hex: "#566C44")
        case .jueJueZi:    return Color(hex: "#6C4D7E")
        case .buBaiLan:    return Color(hex: "#325969")
        case .tangTaiZong: return Color(hex: "#856441")
        case .fangQingSong:return Color(hex: "#518463")
        case .faCaiHong:   return Color(hex: "#CC4968")
        }
    }

    // 配色调色板（4个辅助色）
    var palette: [Color] {
        switch self {
        case .blue:
            return [Color(hex: "#6B9FE4"), Color(hex: "#A8C4E8"), Color(hex: "#D0E4FF"), Color(hex: "#EBF3FF")]
        case .buJiaoLv:
            return [Color(hex: "#7E9966"), Color(hex: "#969571"), Color(hex: "#C8C7A7"), Color(hex: "#DAE2BC")]
        case .jueJueZi:
            return [Color(hex: "#B384BC"), Color(hex: "#ECD9CB"), Color(hex: "#A9D1D9"), Color(hex: "#D4C8A8")]
        case .buBaiLan:
            return [Color(hex: "#6B8FA7"), Color(hex: "#9BB89A"), Color(hex: "#F2CDB4"), Color(hex: "#DDC7DC")]
        case .tangTaiZong:
            return [Color(hex: "#F1C883"), Color(hex: "#9ACAAE"), Color(hex: "#ECDBD6"), Color(hex: "#EDBB77")]
        case .fangQingSong:
            return [Color(hex: "#A7B3B2"), Color(hex: "#CEE2E0"), Color(hex: "#D2C8AC"), Color(hex: "#CEEB83")]
        case .faCaiHong:
            return [Color(hex: "#EAB1B6"), Color(hex: "#F4796A"), Color(hex: "#D2C86C"), Color(hex: "#E2B2D2")]
        }
    }

    // 主题 emoji 标识
    var emoji: String {
        switch self {
        case .blue:        return "✈️"
        case .buJiaoLv:    return "🌿"
        case .jueJueZi:    return "💜"
        case .buBaiLan:    return "🌊"
        case .tangTaiZong: return "☕"
        case .fangQingSong:return "🌲"
        case .faCaiHong:   return "🌺"
        }
    }

    // 浅色背景版（用于卡片、进度条等）
    var lightColor: Color { color.opacity(0.12) }

    // 渐变（用于按钮、进度条）
    var gradient: LinearGradient {
        LinearGradient(colors: [color, palette.first ?? color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Hex 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
    
    // 渐变（用于按钮、进度条）
    var gradient: LinearGradient {
        LinearGradient(colors: [self, self.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
