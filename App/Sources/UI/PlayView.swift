import QuartzCore
import SwiftUI

/// 遊ぶ画面。床に置いた iPhone の、どこに触れても 1 回。真ん中のレコードに輪が重なる瞬間に触れる
struct PlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let game: GameModel

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            YogaMat(corner: 32).padding(8).ignoresSafeArea(edges: .bottom)
            // 触れる面（画面ぜんぶ）。上に重ねた表示は触れるのを邪魔しない
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in game.touchDown() }
                        .onEnded { _ in game.touchUp() }
                )
                .accessibilityElement()
                .accessibilityLabel("触れる面。拍に合わせて、どこでも触れる")
                .accessibilityAddTraits(.allowsDirectInteraction)
            TimelineView(.animation(paused: game.phase == .finished)) { _ in
                let t = game.songTime()
                Group {
                    if hSize == .regular {
                        HStack(spacing: 32) {
                            stage(t).frame(maxWidth: .infinity)
                            sidePanel(t).frame(width: 260)
                        }
                        .padding(32)
                    } else {
                        VStack(spacing: 12) {
                            header(t)
                            stage(t)
                            hint
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                        .padding(.bottom, 24)
                    }
                }
            }
            .allowsHitTesting(false)
            closeButton
            if game.phase == .ready { ReadyPanel(game: game) }
        }
        .onAppear { game.onFinish = { app.finish($0) } }
    }

    // MARK: 部品

    private var closeButton: some View {
        VStack {
            HStack {
                Button { game.quit() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.paper))
                        .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                }
                .accessibilityLabel("やめる")
                Spacer()
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func header(_ t: Double) -> some View {
        VStack(spacing: 4) {
            progressLine(t)
            HStack(alignment: .firstTextBaseline) {
                counter(t)
                Spacer()
                comboView
            }
            .padding(.leading, 48)
        }
    }

    private func progressLine(_ t: Double) -> some View {
        GeometryReader { geo in
            let p = max(0, min(1, t / max(1, game.chart.duration)))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.paper.opacity(0.8))
                Capsule().fill(Theme.skyDeep).frame(width: geo.size.width * p)
            }
        }
        .frame(height: 3)
        .padding(.leading, 48)
    }

    private func counter(_ t: Double) -> some View {
        let s = game.session
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(s.reps)")
                .font(Theme.serif(64, .regular))
                .kerning(-3)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(game.request.endless ? "回" : "/ \(game.chart.notes.count)")
                .font(Theme.serif(20))
                .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.reps) 回")
    }

    private var comboView: some View {
        let combo = game.session.combo
        return VStack(alignment: .trailing, spacing: 0) {
            Text("\(combo)")
                .font(Theme.serif(30, .medium))
                .monospacedDigit()
                .foregroundStyle(combo >= 10 ? Theme.peachDeep : Theme.ink)
            Caption("combo")
        }
        .opacity(combo >= 2 ? 1 : 0.35)
    }

    private var hint: some View {
        Text(game.request.endless ? "3 回続けて外したら終わり。どこに触れても 1 回" : "鼻かあごで、どこに触れても 1 回")
            .font(Theme.text(13))
            .foregroundStyle(Theme.inkSoft)
    }

    private func sidePanel(_ t: Double) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Caption(game.request.song.english)
            Text(game.request.song.title).font(Theme.serif(26, .medium)).foregroundStyle(Theme.ink)
            counter(t)
            comboView
            UpcomingLane(game: game, t: t)
            Spacer()
            hint
        }
        .padding(.top, 40)
    }

    /// 真ん中：レコード・近づく輪・判定
    private func stage(_ t: Double) -> some View {
        let beat = game.chart.beat(atSeconds: t)
        let angle: Angle = reduceMotion ? .zero : .degrees(max(0, t) * 198)
        return GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height) * 0.78
            ZStack {
                // 的（レコードの外の輪）
                Circle().stroke(Theme.paper, lineWidth: 3).frame(width: d * 1.04, height: d * 1.04)
                RecordDisc(label: game.request.song.title, angle: angle, pressed: game.touching && !reduceMotion)
                    .frame(width: d, height: d)
                keepArc(t, d: d)
                approachRing(t, d: d)
                ripple(d: d)
                centerText(t, beat: beat)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 次のノーツが近づく輪：2 拍前に 1.7 倍の大きさで現れ、ノーツの時刻にレコードの縁に重なる
    @ViewBuilder
    private func approachRing(_ t: Double, d: CGFloat) -> some View {
        if game.phase == .playing, let i = game.session.nextIndex {
            let lead = game.chart.secondsPerBeat * 2
            let dt = game.session.time(of: i) - t
            if dt < lead, dt > -JudgeWindow.good {
                let p = max(0, dt / lead)
                let isKeep: Bool = { if case .keep = game.chart.notes[i].kind { true } else { false } }()
                Circle()
                    .stroke(isKeep ? Theme.peachDeep : Theme.skyDeep, lineWidth: isKeep ? 7 : 5)
                    .frame(width: d * 1.04 * (1 + 0.7 * p), height: d * 1.04 * (1 + 0.7 * p))
                    .opacity(1 - p * 0.55)
            }
        }
    }

    /// キープ中：レコードの外を peach の弧がまわる
    @ViewBuilder
    private func keepArc(_ t: Double, d: CGFloat) -> some View {
        if let h = game.session.holding {
            let start = game.session.time(of: h.index), end = game.session.endTime(of: h.index)
            let p = max(0, min(1, (t - start) / max(0.01, end - start)))
            Circle()
                .trim(from: 0, to: p)
                .stroke(Theme.peachDeep, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: d * 1.12, height: d * 1.12)
        }
    }

    /// 判定の波紋（0.45 秒で広がって消える）
    @ViewBuilder
    private func ripple(d: CGFloat) -> some View {
        if let e = game.lastEvent, e.judgement != .miss, !reduceMotion {
            let age = game.eventAge()
            if age < 0.45 {
                let p = age / 0.45
                Circle()
                    .stroke(Theme.color(e.judgement), lineWidth: 3 * (1 - p) + 0.5)
                    .frame(width: d * (1.04 + 0.35 * p), height: d * (1.04 + 0.35 * p))
                    .opacity(1 - p)
            }
        }
    }

    @ViewBuilder
    private func centerText(_ t: Double, beat: Double) -> some View {
        if game.phase == .preparing || (game.phase == .playing && t < 0) {
            countdown(big: "\(Int(max(1, ceil(-t))))", small: "位置について")
        } else if game.phase == .playing, beat < Double(Chart.countIn) {
            countdown(big: "\(Int(beat) + 1)", small: "カウント")
        } else if let e = game.lastEvent {
            let age = game.eventAge()
            if age < 0.7 {
                let pop = reduceMotion ? 1 : 1 + 0.18 * max(0, 1 - age / 0.18)
                Text(e.judgement.label)
                    .font(Theme.serif(34, .medium).italic())
                    .foregroundStyle(Theme.color(e.judgement))
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.paper.opacity(0.92)))
                    .scaleEffect(pop)
                    .opacity(age < 0.5 ? 1 : (0.7 - age) / 0.2)
                    .offset(y: -12)
            }
        }
    }

    private func countdown(big: String, small: String) -> some View {
        VStack(spacing: 0) {
            Text(big).font(Theme.serif(72)).monospacedDigit().foregroundStyle(Theme.ink)
            Caption(small, color: Theme.ink)
        }
        .padding(22)
        .background(Circle().fill(Theme.paper.opacity(0.94)))
    }
}

/// 広い画面の横に出す、次のノーツの列
private struct UpcomingLane: View {
    let game: GameModel
    let t: Double

    var body: some View {
        let upcoming = upcomingNotes()
        VStack(alignment: .leading, spacing: 8) {
            Caption("つぎ")
            ForEach(upcoming) { item in
                HStack(spacing: 10) {
                    Circle().fill(item.keep ? Theme.peach : Theme.sky).frame(width: 10, height: 10)
                    Text(item.keep ? "キープ" : "タッチ").font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(String(format: "%.1f 拍", item.beats)).font(Theme.text(13)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                }
            }
            if upcoming.isEmpty { Text("あと少し").font(Theme.text(14)).foregroundStyle(Theme.inkSoft) }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.paper.opacity(0.85)))
    }

    struct Item: Identifiable {
        let id: Int
        let keep: Bool
        let beats: Double
    }

    private func upcomingNotes() -> [Item] {
        guard let first = game.session.nextIndex else { return [] }
        let now = game.chart.beat(atSeconds: t)
        return (first..<min(first + 4, game.chart.notes.count)).map { i in
            let n = game.chart.notes[i]
            let keep: Bool = { if case .keep = n.kind { true } else { false } }()
            return Item(id: i, keep: keep, beats: max(0, n.beat - now))
        }
    }
}

/// はじめる前：置き方の絵と、はじめるボタン
private struct ReadyPanel: View {
    @Environment(AppModel.self) private var app
    let game: GameModel

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    PlacementSketch().frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 4) {
                        if let plan = game.request.plan {
                            Caption("Day \(plan.day) ・ \(plan.style)")
                        } else {
                            Caption(game.request.endless ? "フリー" : game.request.song.english)
                        }
                        Text(game.request.endless ? "外すまで続ける" : "\(game.chart.notes.count) 回")
                            .font(Theme.serif(30)).kerning(-1).foregroundStyle(Theme.ink)
                        Text("\(game.request.song.title) ・ BPM \(Int(game.request.song.bpm))")
                            .font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                    }
                }
                Text("床に置いて、画面の上側に頭がくるように。押してから 5 秒で始まります。鼻かあごで、どこに触れても 1 回。")
                    .font(Theme.text(14)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("はじめる") { game.begin() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: 520)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
            .shadow(color: Theme.ink.opacity(0.08), radius: 12, y: 6)
            .padding(16)
        }
    }
}

/// 置き方の絵：マットの上の iPhone と、上から近づく頭
struct PlacementSketch: View {
    var headDrop: CGFloat = 0.6

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: h * 0.1, width: w, height: h * 0.85), cornerRadius: 12), with: .color(Theme.mat))
            let phone = CGRect(x: w * 0.32, y: h * 0.38, width: w * 0.36, height: h * 0.52)
            ctx.fill(Path(roundedRect: phone, cornerRadius: 6), with: .color(Theme.ink.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: phone.midX - w * 0.1, y: phone.midY - w * 0.1, width: w * 0.2, height: w * 0.2)), with: .color(Theme.peach))
            // 頭（上から下りてくる）
            let headY = h * (0.02 + 0.22 * headDrop)
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.38, y: headY, width: w * 0.24, height: w * 0.24)), with: .color(Theme.sky))
            var arrow = Path()
            arrow.move(to: CGPoint(x: w * 0.78, y: h * 0.12))
            arrow.addLine(to: CGPoint(x: w * 0.78, y: h * 0.34))
            arrow.move(to: CGPoint(x: w * 0.73, y: h * 0.28))
            arrow.addLine(to: CGPoint(x: w * 0.78, y: h * 0.34))
            arrow.addLine(to: CGPoint(x: w * 0.83, y: h * 0.28))
            ctx.stroke(arrow, with: .color(Theme.skyDeep), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
