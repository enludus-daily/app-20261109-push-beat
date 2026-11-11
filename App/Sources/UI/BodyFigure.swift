import SwiftUI

/// 線の人形（横から見た腕立て）。やり方ごとに姿勢が変わり、効く所に色が付く（主に＝peach、補助＝薄い peach）。
/// 床の上には iPhone（頭が下りる先）を置く。自作の Canvas
struct BodyFigure: View {
    let technique: Technique
    /// 色を付ける筋肉と強さ（既定はやり方の効く所）
    var load: [Muscle: Double]?
    /// 1 つの筋肉だけを強く見せる（筋肉の入口で使う）
    var focus: Muscle?
    var showPhone = true

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * w, y: p.y * h) }
            let pose = Pose.of(technique)
            let line = max(1.6, h * 0.035)

            // 床
            var floor = Path()
            floor.move(to: pt(CGPoint(x: 0.04, y: 0.92)))
            floor.addLine(to: pt(CGPoint(x: 0.98, y: 0.92)))
            ctx.stroke(floor, with: .color(Theme.matRib), lineWidth: Theme.hairline * 2)

            // 台（デクライン）
            if let box = pose.box {
                let r = CGRect(x: box.minX * w, y: box.minY * h, width: box.width * w, height: box.height * h)
                ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(Theme.skySoft))
                ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(Theme.sky), lineWidth: Theme.hairline * 2)
            }

            // iPhone（頭が下りる先）
            if showPhone {
                let c = pt(pose.phone)
                let r = CGRect(x: c.x - w * 0.06, y: c.y - h * 0.025, width: w * 0.12, height: h * 0.05)
                ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(Theme.skyDeep.opacity(0.8)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - h * 0.012, y: c.y - h * 0.012, width: h * 0.024, height: h * 0.024)),
                         with: .color(Theme.peach))
            }

            // 効く所（体の線より先に、太い帯で塗る）
            let weights = load ?? technique.load
            func strength(_ m: Muscle) -> Double {
                if let focus { return m == focus ? 1 : 0 }
                return weights[m] ?? 0
            }
            func color(_ s: Double) -> Color { s >= 1 ? Theme.peach : Theme.peach.opacity(0.42) }
            let band = h * 0.11
            func along(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
                CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            let shoulder = pt(pose.shoulder), hip = pt(pose.hip), elbow = pt(pose.elbow)
            // 胸：肩から腰へ 0〜35% の、床側
            let s1 = strength(.chest)
            if s1 > 0 {
                var p = Path()
                let a = along(shoulder, hip, 0.04), b = along(shoulder, hip, 0.34)
                p.move(to: CGPoint(x: a.x, y: a.y + band * 0.28))
                p.addLine(to: CGPoint(x: b.x, y: b.y + band * 0.28))
                ctx.stroke(p, with: .color(color(s1)), style: StrokeStyle(lineWidth: band, lineCap: .round))
            }
            // 体幹：肩から腰へ 40〜95%
            let s2 = strength(.core)
            if s2 > 0 {
                var p = Path()
                p.move(to: along(shoulder, hip, 0.42))
                p.addLine(to: along(shoulder, hip, 0.98))
                ctx.stroke(p, with: .color(color(s2)), style: StrokeStyle(lineWidth: band * 0.9, lineCap: .round))
            }
            // 二の腕：肩からひじ
            let s3 = strength(.triceps)
            if s3 > 0 {
                var p = Path()
                p.move(to: along(shoulder, elbow, 0.15))
                p.addLine(to: along(shoulder, elbow, 0.92))
                ctx.stroke(p, with: .color(color(s3)), style: StrokeStyle(lineWidth: band * 0.72, lineCap: .round))
            }
            // 肩の前：肩の丸
            let s4 = strength(.shoulder)
            if s4 > 0 {
                let r = band * 0.62
                ctx.fill(Path(ellipseIn: CGRect(x: shoulder.x - r, y: shoulder.y - r, width: r * 2, height: r * 2)), with: .color(color(s4)))
            }

            // 体の線
            let ink = GraphicsContext.Shading.color(Theme.ink.opacity(0.78))
            let style = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            var bodyPath = Path()
            bodyPath.move(to: pt(pose.hand))
            bodyPath.addLine(to: elbow)
            bodyPath.addLine(to: shoulder)
            bodyPath.addLine(to: hip)
            bodyPath.addLine(to: pt(pose.knee))
            bodyPath.addLine(to: pt(pose.foot))
            ctx.stroke(bodyPath, with: ink, style: style)
            // 首と頭
            let head = pt(pose.head)
            var neck = Path()
            neck.move(to: shoulder)
            neck.addLine(to: along(shoulder, head, 0.6))
            ctx.stroke(neck, with: ink, style: style)
            let hr = h * 0.075
            let headRect = CGRect(x: head.x - hr, y: head.y - hr, width: hr * 2, height: hr * 2)
            ctx.fill(Path(ellipseIn: headRect), with: .color(Theme.paper))
            ctx.stroke(Path(ellipseIn: headRect), with: ink, lineWidth: line)

            // やり方のしるし（手の幅・下ろす向き）
            if let mark = pose.mark {
                let text = ctx.resolve(Text(mark).font(.system(size: max(8, h * 0.13), weight: .medium)).foregroundStyle(Theme.skyDeep))
                ctx.draw(text, at: pt(pose.markAt), anchor: .center)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let focus { return "\(focus.label)に効く姿勢の絵" }
        let main = technique.mainMuscles.map(\.label).joined(separator: "・")
        return "\(technique.title)の姿勢。主に\(main)"
    }
}

/// 横から見た姿勢（0〜1 の座標。頭が左）
private struct Pose {
    var head: CGPoint
    var shoulder: CGPoint
    var elbow: CGPoint
    var hand: CGPoint
    var hip: CGPoint
    var knee: CGPoint
    var foot: CGPoint
    var phone: CGPoint
    var box: CGRect?
    var mark: String?
    var markAt = CGPoint(x: 0.5, y: 0.2)

    /// 肩から足先までまっすぐな板（腕は少し曲げた、下りる途中）
    static func plank(shoulderY: CGFloat = 0.6, handX: CGFloat = 0.27, elbow: CGPoint = CGPoint(x: 0.37, y: 0.76)) -> Pose {
        let shoulder = CGPoint(x: 0.27, y: shoulderY)
        let foot = CGPoint(x: 0.93, y: 0.86)
        func on(_ x: CGFloat) -> CGPoint {
            CGPoint(x: x, y: shoulder.y + (foot.y - shoulder.y) * (x - shoulder.x) / (foot.x - shoulder.x))
        }
        return Pose(head: CGPoint(x: 0.14, y: shoulderY - 0.05), shoulder: shoulder, elbow: elbow,
                    hand: CGPoint(x: handX, y: 0.9), hip: on(0.6), knee: on(0.77), foot: foot,
                    phone: CGPoint(x: 0.13, y: 0.9))
    }

    static func of(_ t: Technique) -> Pose {
        switch t {
        case .standard:
            return plank()
        case .wide:
            var p = plank(elbow: CGPoint(x: 0.36, y: 0.79))
            p.mark = "↔"
            p.markAt = CGPoint(x: 0.27, y: 0.38)
            return p
        case .diamond:
            var p = plank(handX: 0.31, elbow: CGPoint(x: 0.43, y: 0.74))
            p.mark = "◇"
            p.markAt = CGPoint(x: 0.31, y: 0.38)
            return p
        case .negative:
            var p = plank()
            p.mark = "↓"
            p.markAt = CGPoint(x: 0.14, y: 0.28)
            return p
        case .knee:
            let shoulder = CGPoint(x: 0.27, y: 0.6)
            let knee = CGPoint(x: 0.72, y: 0.89)
            return Pose(head: CGPoint(x: 0.14, y: 0.55), shoulder: shoulder, elbow: CGPoint(x: 0.37, y: 0.76),
                        hand: CGPoint(x: 0.27, y: 0.9), hip: CGPoint(x: 0.55, y: 0.78), knee: knee,
                        foot: CGPoint(x: 0.9, y: 0.72), phone: CGPoint(x: 0.13, y: 0.9))
        case .hold:
            let shoulder = CGPoint(x: 0.27, y: 0.75)
            return Pose(head: CGPoint(x: 0.14, y: 0.73), shoulder: shoulder, elbow: CGPoint(x: 0.4, y: 0.76),
                        hand: CGPoint(x: 0.28, y: 0.9), hip: CGPoint(x: 0.6, y: 0.8), knee: CGPoint(x: 0.77, y: 0.83),
                        foot: CGPoint(x: 0.93, y: 0.86), phone: CGPoint(x: 0.13, y: 0.9), mark: "…", markAt: CGPoint(x: 0.27, y: 0.5))
        case .decline:
            return Pose(head: CGPoint(x: 0.14, y: 0.62), shoulder: CGPoint(x: 0.27, y: 0.64), elbow: CGPoint(x: 0.37, y: 0.78),
                        hand: CGPoint(x: 0.27, y: 0.9), hip: CGPoint(x: 0.58, y: 0.58), knee: CGPoint(x: 0.74, y: 0.56),
                        foot: CGPoint(x: 0.9, y: 0.53), phone: CGPoint(x: 0.13, y: 0.9),
                        box: CGRect(x: 0.82, y: 0.56, width: 0.16, height: 0.36))
        case .pike:
            return Pose(head: CGPoint(x: 0.25, y: 0.74), shoulder: CGPoint(x: 0.36, y: 0.58), elbow: CGPoint(x: 0.43, y: 0.76),
                        hand: CGPoint(x: 0.33, y: 0.9), hip: CGPoint(x: 0.6, y: 0.22), knee: CGPoint(x: 0.74, y: 0.54),
                        foot: CGPoint(x: 0.86, y: 0.88), phone: CGPoint(x: 0.22, y: 0.9))
        }
    }
}
