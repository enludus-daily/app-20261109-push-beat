import SwiftUI

// 色・書体・形は、ここだけで決める（StudyReel のトーン：淡い sky ＋ peach の差し色、セリフの見出しと数字、細い線、弱い影）。
// 基準は .claude/skills/app-quality-bar/references/look.md §0。確かめ方：python3 scripts/tone-check.py
enum Theme {
    // 地と文字
    static let ground = Color(hex: 0xF3F6F9)
    static let paper = Color(hex: 0xF7F8FA)
    static let ink = Color(hex: 0x2E3A46)
    static let inkSoft = Color(hex: 0x8E9AA6)
    static let line = Color(hex: 0xE3E9EF)

    // 主の色 sky（5 段階）
    static let sky = Color(hex: 0x9EC3E2)
    static let skySoft = Color(hex: 0xE1EDF6)
    static let skyDeep = Color(hex: 0x5E8DB8)
    static let skyMist = Color(hex: 0xEEF4FA)

    // 差し色 peach（判定 Perfect・今日のマス・レコードのラベル）
    static let peach = Color(hex: 0xF4BBA4)
    static let peachSoft = Color(hex: 0xFBE7DE)
    static let peachDeep = Color(hex: 0xC98468)

    // ヨガマット
    static let mat = Color(hex: 0xDCE8F2)
    static let matRib = Color(hex: 0xCFDDEA)

    /// 判定ごとの色（意味のある段階）：Perfect は peach、Good は sky、Miss は灰
    static func color(_ j: Judgement) -> Color {
        switch j {
        case .perfect: peachDeep
        case .good: skyDeep
        case .miss: inkSoft
        }
    }

    /// 回数の多さで 5 段階（記録の棒・30 日の道）
    static func level(_ reps: Int) -> Color {
        switch reps {
        case 0: line
        case 1..<10: skySoft
        case 10..<20: sky
        case 20..<40: skyDeep.opacity(0.75)
        default: skyDeep
        }
    }

    // 書体：見出しと数字はセリフ、本文はサンセリフ
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .serif) }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium) }

    // 角丸の段階
    static let rSmall: CGFloat = 6
    static let rMid: CGFloat = 12
    static let rCard: CGFloat = 18

    static let hairline: CGFloat = 0.6
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// 小さなラベル（字間を開ける。雑誌のキャプションのように）
struct Caption: View {
    let text: String
    var color: Color = Theme.inkSoft
    init(_ text: String, color: Color = Theme.inkSoft) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(Theme.label(11)).kerning(1.2).foregroundStyle(color)
    }
}

/// 主なボタン：deep の地に白い文字、高さ 54
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.skyDeep
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(16, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(fill))
            .shadow(color: Theme.skyDeep.opacity(0.18), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 2 つめのボタン：細い線の枠
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(14, .medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 淡い地の上の、白い板（カードの代わりに、マットの上に置いた薄い板）
struct Slab<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }
}
