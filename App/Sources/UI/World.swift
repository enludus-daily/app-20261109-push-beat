import SwiftUI

// 世界観の部品：このアプリでは「ヨガマット」が画面の地になり、「レコード盤」が叩く的になる。
// 曲は「レコードのジャケット」で並ぶ。

/// ヨガマット：淡い水色の地に、横の細い溝。上の端は巻いた跡（2 本の線）
struct YogaMat: View {
    var corner: CGFloat = 28

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let shape = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)
            ctx.fill(shape, with: .color(Theme.mat))
            ctx.clip(to: shape)
            // マットの溝（14pt おき、線 0.6）
            var y: CGFloat = 22
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(Theme.matRib), lineWidth: Theme.hairline)
                y += 14
            }
            // 巻いた跡（上の端）
            for (i, alpha) in [(0, 0.9), (1, 0.5)] {
                var p = Path()
                let yy = CGFloat(8 + i * 5)
                p.move(to: CGPoint(x: 0, y: yy))
                p.addLine(to: CGPoint(x: size.width, y: yy))
                ctx.stroke(p, with: .color(Theme.paper.opacity(alpha)), lineWidth: 1.2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// レコード盤。溝の輪・peach のラベル・中心の穴。angle で回る（時刻から計算。repeatForever は使わない）
struct RecordDisc: View {
    var label: String = ""
    var angle: Angle = .zero
    var pressed = false

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Theme.ink.opacity(0.88))
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2
                    var rr = r * 0.95
                    var i = 0
                    while rr > r * 0.4 {
                        let p = Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
                        ctx.stroke(p, with: .color(.white.opacity(i % 3 == 0 ? 0.12 : 0.05)), lineWidth: Theme.hairline)
                        rr -= r * 0.035
                        i += 1
                    }
                    // 光の反射：溝に沿った細い弧を 2 本だけ（太い帯にすると汚れに見える。監督のレビュー #12）
                    for (radius, from, to, alpha) in [(0.82, -64.0, -26.0, 0.32), (0.66, -58.0, -36.0, 0.2)] {
                        var glint = Path()
                        glint.addArc(center: c, radius: r * radius, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
                        ctx.stroke(glint, with: .color(.white.opacity(alpha)), style: StrokeStyle(lineWidth: max(1, r * 0.018), lineCap: .round))
                    }
                }
                .rotationEffect(angle)
                Circle().fill(Theme.peach).frame(width: d * 0.38, height: d * 0.38)
                Circle().stroke(Theme.paper.opacity(0.7), lineWidth: Theme.hairline).frame(width: d * 0.33, height: d * 0.33)
                Text(d >= 150 ? label : "")
                    .font(Theme.serif(max(10, d * 0.045), .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: d * 0.3)
                    .offset(y: -d * 0.08)
                    .rotationEffect(angle)
                Circle().fill(Theme.ground).frame(width: d * 0.035, height: d * 0.035)
            }
            .frame(width: d, height: d)
            .scaleEffect(pressed ? 0.965 : 1)
            .shadow(color: Theme.ink.opacity(0.12), radius: 14, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// レコードのジャケット。曲の雰囲気ごとに、sky と peach だけで違う構図を描く（色は 1 系統のまま）
struct Jacket: View {
    let song: Song
    var locked = false

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(roundedRect: rect, cornerRadius: Theme.rSmall, style: .continuous), with: .color(Theme.skyMist))
            ctx.clip(to: Path(roundedRect: rect, cornerRadius: Theme.rSmall, style: .continuous))
            let seed = song.id.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            switch song.mood {
            case .latte:  // カップの湯気の 3 本の曲線と丸
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.2, y: h * 0.42, width: w * 0.6, height: w * 0.6)), with: .color(Theme.peach))
                for i in 0..<3 {
                    var p = Path()
                    let x = w * (0.35 + 0.15 * CGFloat(i))
                    p.move(to: CGPoint(x: x, y: h * 0.38))
                    p.addCurve(to: CGPoint(x: x, y: h * 0.1), control1: CGPoint(x: x - w * 0.08, y: h * 0.28), control2: CGPoint(x: x + w * 0.08, y: h * 0.2))
                    ctx.stroke(p, with: .color(Theme.skyDeep.opacity(0.6)), lineWidth: 1.2)
                }
            case .soda:  // 泡
                for i in 0..<9 {
                    let r = w * CGFloat(0.04 + Double((seed >> i) & 3) * 0.03)
                    let x = w * CGFloat(0.15 + Double((seed &* (i + 3)) % 70) / 100)
                    let y = h * CGFloat(0.12 + Double(i) * 0.09)
                    ctx.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(Theme.skyDeep.opacity(0.55)), lineWidth: 1)
                }
                ctx.fill(Path(CGRect(x: 0, y: h * 0.78, width: w, height: h * 0.22)), with: .color(Theme.sky))
            case .sunset:  // 地平線に沈む半円
                ctx.fill(Path(CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.38)), with: .color(Theme.sky))
                var sun = Path()
                sun.addArc(center: CGPoint(x: w * 0.5, y: h * 0.62), radius: w * 0.26, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                ctx.fill(sun, with: .color(Theme.peach))
                for i in 0..<3 {
                    ctx.fill(Path(CGRect(x: w * 0.2, y: h * (0.7 + 0.07 * CGFloat(i)), width: w * 0.6 - CGFloat(i) * w * 0.15, height: 1.2)), with: .color(Theme.paper))
                }
            case .rain:  // 斜めの雨の線
                for i in 0..<14 {
                    var p = Path()
                    let x = w * CGFloat(i) / 10 - w * 0.2
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + w * 0.3, y: h))
                    ctx.stroke(p, with: .color(Theme.skyDeep.opacity(i % 3 == 0 ? 0.5 : 0.22)), lineWidth: 0.8)
                }
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.56, y: h * 0.16, width: w * 0.22, height: w * 0.22)), with: .color(Theme.peach))
            case .citrus:  // 輪切りの果物
                let c = CGPoint(x: w * 0.5, y: h * 0.5)
                let r = w * 0.32
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Theme.peach))
                for k in 0..<8 {
                    var p = Path()
                    p.move(to: c)
                    let a = Double(k) * .pi / 4 + Double(seed % 10) / 10
                    p.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.9, y: c.y + sin(a) * r * 0.9))
                    ctx.stroke(p, with: .color(Theme.paper), lineWidth: 1.4)
                }
            case .night:  // 月と星
                ctx.fill(Path(rect), with: .color(Theme.sky))
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.55, y: h * 0.14, width: w * 0.24, height: w * 0.24)), with: .color(Theme.paper))
                for i in 0..<7 {
                    let x = w * CGFloat((seed &* (i + 5)) % 90) / 100
                    let y = h * CGFloat(0.4 + Double((seed >> i) % 50) / 100)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.4, height: 2.4)), with: .color(Theme.paper))
                }
            }
            // 曲名を下に（雑誌のような小さな字）
            let title = ctx.resolve(Text(song.english.uppercased()).font(.system(size: max(7, w * 0.07), weight: .semibold)).kerning(1).foregroundStyle(Theme.ink))
            ctx.draw(title, at: CGPoint(x: w * 0.08, y: h * 0.92), anchor: .leading)
        }
        .overlay {
            if locked {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).fill(Theme.paper.opacity(0.45))
                    Image(systemName: "lock.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                        .padding(8).background(Circle().fill(Theme.paper))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Theme.ink.opacity(0.08), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

/// 難しさの点（5 つ）
struct LevelDots: View {
    let level: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle().fill(i <= level ? Theme.skyDeep : Theme.line).frame(width: 5, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(L("むずかしさ %@", "\(level)"))
    }
}
