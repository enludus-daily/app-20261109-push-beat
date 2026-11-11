import SwiftUI

/// 結果：段階・数え上がる数字のタイル・くせ・道の進み・共有
struct ResultView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: ResultSummary
    @State private var shown: Double = 0
    @State private var shareImage: Image?
    @State private var acceptedAdvice = false
    @State private var usedBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                top
                if hSize == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) { tiles; nextCards }
                        VStack(spacing: 16) { tendencyCard; planCard }
                    }
                } else {
                    tiles
                    nextCards
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
        if result.practice { return L("ためし") }
        if result.measure { return L("いまの自分") }
        if result.record.endless { return L("エンドレス") }
        if result.quit { return L("途中まで") }
        return "Result"
    }

    private var subline: String {
        if result.practice { return L("つかめたら、次は床に置いて腕立てで") }
        if result.measure { return L("%@ 回できた。これが、いまの自分", "\(result.record.reps)") }
        if result.quit, !result.record.endless { return L("ここまでの記録も残しました") }
        return result.grade.line
    }

    private var homeTitle: String { result.practice ? L("今日の 1 曲へ") : L("ホームへ") }

    private var top: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Caption(headline)
                Text(result.song.title).font(Theme.serif(26, .medium)).foregroundStyle(Theme.ink)
                Text(subline)
                    .font(Theme.text(14)).foregroundStyle(Theme.inkSoft)
                if !result.practice {
                    Text(L("やり方：%@ ・ 主に", "\(result.record.resolvedTechnique.title)") + result.record.resolvedTechnique.mainMuscles.map(\.label).joined(separator: L("・")))
                        .font(Theme.text(12, .medium)).foregroundStyle(Theme.skyDeep)
                }
                if result.newBest {
                    Text(L("エンドレスの自己ベスト更新")).font(Theme.text(12, .semibold)).foregroundStyle(Theme.peachDeep)
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
            .accessibilityLabel(L("段階 %@", "\(result.grade.rawValue)"))
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
                Text(L("回")).font(Theme.serif(22)).foregroundStyle(Theme.inkSoft)
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

    /// 結果の次の一歩：回数の提案・ためした回数で道を作る・エンドレスのベストとの差
    @ViewBuilder private var nextCards: some View {
        if result.measure, !result.practice { measureCard }
        if result.plan != nil, !result.record.endless, !result.practice { adviceCard }
        if let before = result.endlessBefore { endlessCompare(before) }
    }

    /// 次の回数の提案（勝手に変えず、1 タップで受け入れる）
    private var adviceCard: some View {
        let advice = result.advice
        let r = result.record
        let n = r.perfect + r.good + r.miss
        let perfectPct = n == 0 ? 0 : Int((Double(r.perfect) / Double(n) * 100).rounded())
        return Slab {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption(L("次の回数"))
                    Spacer()
                    Text(L("Perfect %@%% ・ %@", "\(perfectPct)", "\(result.quit ? L("途中まで") : L("最後まで"))"))
                        .font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                }
                switch advice {
                case .keep:
                    Text(L("ちょうどいい回数です")).font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
                    Text(L("Day %@ は %@ 回。きつければホームの −／＋ でいつでも変えられます", "\(result.nextDay)", "\(result.nextReps)"))
                        .font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                case .up, .down:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(advice.delta > 0 ? L("少し上げてみる？") : L("少し下げてみる？")).font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(result.nextReps)").font(Theme.serif(20)).monospacedDigit().foregroundStyle(Theme.inkSoft).strikethrough(acceptedAdvice)
                        Image(systemName: "arrow.right").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                        Text(L("%@ 回", "\(result.nextRepsAfter)")).font(Theme.serif(26, .medium)).monospacedDigit()
                            .foregroundStyle(advice.delta > 0 ? Theme.peachDeep : Theme.skyDeep)
                    }
                    Text(advice.delta > 0
                         ? L("Perfect が多く、最後まで続きました。Day %@ から %@ 回ふやす提案です", "\(result.nextDay)", "\(advice.delta)")
                         : (result.quit ? L("今日は途中まで。Day %@ から %@ 回へらして、最後まで続けよう", "\(result.nextDay)", "\(-advice.delta)")
                                        : L("外した回が多め。Day %@ から %@ 回へらして、拍に乗ろう", "\(result.nextDay)", "\(-advice.delta)")))
                        .font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    if acceptedAdvice {
                        Label(L("Day %@ から %@ 回にしました", "\(result.nextDay)", "\(result.nextRepsAfter)"), systemImage: "checkmark")
                            .font(Theme.text(13, .medium)).foregroundStyle(Theme.skyDeep)
                    } else {
                        HStack(spacing: 10) {
                            Button(advice.delta > 0 ? L("+%@ 回にする", "\(advice.delta)") : L("%@ 回にする", "\(advice.delta)")) {
                                app.acceptAdvice(advice)
                                withAnimation(.easeOut(duration: 0.25)) { acceptedAdvice = true }
                            }
                            .buttonStyle(PrimaryButtonStyle(fill: advice.delta > 0 ? Theme.peachDeep : Theme.skyDeep))
                            Button(L("このまま")) { withAnimation(.easeOut(duration: 0.25)) { acceptedAdvice = true } }
                                .buttonStyle(QuietButtonStyle())
                                .frame(maxWidth: 110)
                        }
                    }
                }
            }
        }
    }

    /// ためした回数で、30 日の道を作る
    private var measureCard: some View {
        Slab {
            VStack(alignment: .leading, spacing: 10) {
                Caption(L("いまの自分の回数"))
                if usedBaseline {
                    Label(L("%@ 回で 30 日の道を作りました", "\(result.record.reps)"), systemImage: "checkmark")
                        .font(Theme.text(14, .medium)).foregroundStyle(Theme.skyDeep)
                } else {
                    Text(L("%@ 回をもとに、30 日の回数を合わせますか？", "\(result.record.reps)")).font(Theme.text(14)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PlanPreview(baseline: max(1, result.record.reps), course: app.course)
                if !usedBaseline {
                    Button(L("この回数で道を作る")) {
                        app.useAsBaseline(max(1, result.record.reps))
                        withAnimation(.easeOut(duration: 0.25)) { usedBaseline = true }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    /// エンドレス：今回と自己ベストを並べる
    private func endlessCompare(_ before: EndlessBest) -> some View {
        let r = result.record
        return Slab {
            VStack(alignment: .leading, spacing: 10) {
                Caption(L("自己ベストと比べる"))
                HStack(spacing: 0) {
                    compareColumn(L("回数"), r.reps, before.reps, format: { "\($0)" })
                    compareColumn(L("コンボ"), r.maxCombo, before.combo, format: { "\($0)" })
                    compareColumn(L("続いた時間"), r.seconds ?? 0, before.seconds, format: { Self.time($0) })
                }
            }
        }
    }

    private func compareColumn(_ label: String, _ now: Int, _ best: Int, format: (Int) -> String) -> some View {
        let diff = now - best
        let nowText = format(now)
        let note: String = best == 0 ? L("はじめて") : (diff > 0 ? L("ベスト +") + format(diff) : (diff == 0 ? L("ベストと同じ") : L("ベストまで ") + format(-diff)))
        return VStack(spacing: 3) {
            Text(nowText).font(Theme.serif(26, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(note)
                .font(Theme.text(11, .semibold)).monospacedDigit()
                .foregroundStyle(diff > 0 ? Theme.peachDeep : Theme.inkSoft)
            Caption(label)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    static func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    private var tendencyCard: some View {
        Slab {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption(L("タイミングのくせ"))
                    Spacer()
                    Text(L("%@（%@%@ ms）", "\(result.tendency.label)", "\(result.record.meanOffsetMs > 0 ? "+" : "")", "\(result.record.meanOffsetMs)"))
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
                        Text(L("Day %@ クリア", "\(plan.day)")).font(Theme.serif(24, .medium)).foregroundStyle(Theme.ink)
                    } else if let plan = result.plan {
                        Caption("\(plan.course.title)")
                        Text(result.quit ? L("Day %@ はまた今度", "\(plan.day)") : L("Day %@ をもう一度", "\(plan.day)")).font(Theme.serif(22, .medium)).foregroundStyle(Theme.ink)
                    } else {
                        Caption(L("これまで"))
                        Text(L("%@ 回", "\(result.totalReps)")).font(Theme.serif(24, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                    Text(result.streak > 1 ? L("%@ 日連続 ・ 合計 %@ 回", "\(result.streak)", "\(result.totalReps)") : L("合計 %@ 回", "\(result.totalReps)"))
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
                Button(L("もう一回")) { app.replay() }.buttonStyle(QuietButtonStyle())
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(L("うでたてビートの記録"), image: shareImage)) {
                        Label(L("記録を共有"), systemImage: "square.and.arrow.up")
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
                Text(L("はやい")).font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
                Spacer()
                Text(L("おそい")).font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
            }
            .offset(y: 16)
        }
        .padding(.bottom, 14)
        .accessibilityElement()
        .accessibilityLabel(L("タイミングのくせ %@ ミリ秒", "\(ms)"))
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
                Caption(L("Push Beat ・ うでたてビート"))
                Spacer()
                RecordDisc(label: result.song.title).frame(width: 220, height: 220).frame(maxWidth: .infinity)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(result.record.reps)").font(Theme.serif(96)).kerning(-4).monospacedDigit().foregroundStyle(Theme.ink)
                    Text(L("回")).font(Theme.serif(24)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Text(result.grade.rawValue).font(Theme.serif(56, .medium).italic()).foregroundStyle(Theme.peachDeep)
                }
                Text(L("Perfect %@ ・ Good %@ ・ Combo %@", "\(result.record.perfect)", "\(result.record.good)", "\(result.record.maxCombo)"))
                    .font(Theme.text(14, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                Text(result.song.title + L(" ・ ") + result.record.resolvedTechnique.title + (result.plan.map { L(" ・ Day %@", "\($0.day)") } ?? ""))
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
