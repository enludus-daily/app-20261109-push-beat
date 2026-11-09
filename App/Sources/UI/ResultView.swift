import SwiftUI

/// 結果：段階・数え上がる数字のタイル・くせ・道の進み・共有
struct ResultView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: ResultSummary
    @State private var shown: Double = 0
    @State private var shareImage: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                top
                if hSize == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        tiles
                        VStack(spacing: 16) { tendencyCard; planCard }
                    }
                } else {
                    tiles
                    tendencyCard
                    planCard
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            buttons
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Theme.ground.opacity(0.96).ignoresSafeArea())
        }
        .background(Theme.ground.ignoresSafeArea())
        .task {
            shareImage = ShareCard(result: result).rendered()
            if reduceMotion { shown = 1 } else {
                for step in 1...24 {
                    try? await Task.sleep(for: .milliseconds(33))
                    withAnimation(.easeOut(duration: 0.05)) { shown = Double(step) / 24 }
                }
            }
            try? await Task.sleep(for: .milliseconds(900))
            app.maybeShowProAfterResult()
        }
    }

    private var headline: String {
        if result.practice { return "ためし" }
        if result.quit { return "途中まで" }
        return result.record.endless ? "フリー" : "Result"
    }

    private var subline: String {
        if result.practice { return "つかめたら、次は床に置いて腕立てで" }
        if result.quit { return "ここまでの記録も残しました" }
        return result.grade.line
    }

    private var homeTitle: String { result.practice ? "今日の 1 曲へ" : "ホームへ" }

    private var top: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Caption(headline)
                Text(result.song.title).font(Theme.serif(26, .medium)).foregroundStyle(Theme.ink)
                Text(subline)
                    .font(Theme.text(14)).foregroundStyle(Theme.inkSoft)
                if result.newBest {
                    Text("フリーの自己ベスト更新").font(Theme.text(12, .semibold)).foregroundStyle(Theme.peachDeep)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Theme.peachSoft))
                }
            }
            Spacer()
            ZStack {
                RecordDisc(label: "", angle: .degrees(shown * 120)).frame(width: 104, height: 104)
                Text(result.grade.rawValue)
                    .font(Theme.serif(44, .medium).italic())
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityElement()
            .accessibilityLabel("段階 \(result.grade.rawValue)")
        }
    }

    private var tiles: some View {
        let r = result.record
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int((Double(r.reps) * shown).rounded()))")
                    .font(Theme.serif(84))
                    .kerning(-4)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("回").font(Theme.serif(22)).foregroundStyle(Theme.inkSoft)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Caption("max combo")
                    Text("\(Int((Double(r.maxCombo) * shown).rounded()))").font(Theme.serif(30, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                }
            }
            HStack(spacing: 10) {
                tile(.perfect, r.perfect)
                tile(.good, r.good)
                tile(.miss, r.miss)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
        .accessibilityElement(children: .combine)
    }

    private func tile(_ j: Judgement, _ n: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(Int((Double(n) * shown).rounded()))")
                .font(Theme.serif(28, .medium)).monospacedDigit()
                .foregroundStyle(Theme.color(j))
                .contentTransition(.numericText())
            Caption(j.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(j == .perfect ? Theme.peachSoft : (j == .good ? Theme.skyMist : Theme.ground)))
    }

    private var tendencyCard: some View {
        Slab {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("タイミングのくせ")
                    Spacer()
                    Text("\(result.tendency.label)（\(result.record.meanOffsetMs > 0 ? "+" : "")\(result.record.meanOffsetMs) ms）")
                        .font(Theme.text(13, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                TendencyMeter(ms: result.record.meanOffsetMs)
                Text(result.tendency.advice).font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var planCard: some View {
        Slab {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    if let plan = result.plan, result.clearedPlan {
                        Caption("\(plan.course.title)")
                        Text("Day \(plan.day) クリア").font(Theme.serif(24, .medium)).foregroundStyle(Theme.ink)
                    } else if let plan = result.plan {
                        Caption("\(plan.course.title)")
                        Text(result.quit ? "Day \(plan.day) はまた今度" : "Day \(plan.day) をもう一度").font(Theme.serif(22, .medium)).foregroundStyle(Theme.ink)
                    } else {
                        Caption("これまで")
                        Text("\(result.totalReps) 回").font(Theme.serif(24, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                    Text(result.streak > 1 ? "\(result.streak) 日連続 ・ 合計 \(result.totalReps) 回" : "合計 \(result.totalReps) 回")
                        .font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                if let plan = result.plan {
                    MiniPath(course: plan.course, current: plan.day, cleared: result.clearedPlan)
                }
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button(homeTitle) { app.goHome() }.buttonStyle(PrimaryButtonStyle())
            HStack(spacing: 10) {
                Button("もう一回") { app.replay() }.buttonStyle(QuietButtonStyle())
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("うでたてビートの記録", image: shareImage)) {
                        Label("記録を共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
    }
}

/// くせのメーター：真ん中が「ちょうど」、左がはやめ、右がおそめ（±150 ms）
struct TendencyMeter: View {
    let ms: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = w / 2 + CGFloat(max(-150, min(150, ms))) / 150 * (w / 2 - 8)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.skyMist).frame(height: 8)
                Capsule().fill(Theme.sky.opacity(0.5)).frame(width: w * 0.27, height: 8).offset(x: w * 0.365)
                Rectangle().fill(Theme.inkSoft).frame(width: 1, height: 16).offset(x: w / 2)
                Circle().fill(Theme.peachDeep).frame(width: 14, height: 14).offset(x: x - 7)
            }
            .frame(height: 18)
        }
        .frame(height: 18)
        .overlay(alignment: .bottom) {
            HStack {
                Text("はやい").font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("おそい").font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
            }
            .offset(y: 16)
        }
        .padding(.bottom, 14)
        .accessibilityElement()
        .accessibilityLabel("タイミングのくせ \(ms) ミリ秒")
    }
}

/// 道の一部（前後 3 マス）
struct MiniPath: View {
    let course: Course
    let current: Int
    let cleared: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(max(1, current - 2)...min(Program.length, current + 2), id: \.self) { d in
                let done = d < current || (d == current && cleared)
                Circle()
                    .fill(done ? Theme.skyDeep : Theme.paper)
                    .overlay(Circle().stroke(d == current ? Theme.peachDeep : Theme.line, lineWidth: d == current ? 2 : 1))
                    .frame(width: d == current ? 18 : 12, height: d == current ? 18 : 12)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 共有カード（360×640 を 3 倍で書き出す）
struct ShareCard: View {
    let result: ResultSummary

    var body: some View {
        ZStack {
            Theme.ground
            YogaMat(corner: 28).padding(14)
            VStack(alignment: .leading, spacing: 14) {
                Caption("Push Beat ・ うでたてビート")
                Spacer()
                RecordDisc(label: result.song.title).frame(width: 220, height: 220).frame(maxWidth: .infinity)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(result.record.reps)").font(Theme.serif(96)).kerning(-4).monospacedDigit().foregroundStyle(Theme.ink)
                    Text("回").font(Theme.serif(24)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Text(result.grade.rawValue).font(Theme.serif(56, .medium).italic()).foregroundStyle(Theme.peachDeep)
                }
                Text("Perfect \(result.record.perfect) ・ Good \(result.record.good) ・ Combo \(result.record.maxCombo)")
                    .font(Theme.text(14, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                Text(result.song.title + (result.plan.map { " ・ Day \($0.day)" } ?? ""))
                    .font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
            }
            .padding(34)
        }
        .frame(width: 360, height: 640)
    }

    @MainActor
    func rendered() -> Image? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
