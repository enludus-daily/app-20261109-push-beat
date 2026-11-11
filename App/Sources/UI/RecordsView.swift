import Charts
import SwiftUI

/// 記録：積み上げ（無料は 7 日）・くせ。Pro は 30 日の回数・くせの移り変わり・1 回ずつの記録
struct RecordsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if app.progress.records.isEmpty {
                        empty
                    } else {
                        summary
                        WeekBars()
                        WeekTechniques()
                        tendency
                        if app.isPro { ProRecords() } else { lockedPreview }
                    }
                }
                .padding(18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            RecordDisc(label: "", angle: .zero).frame(width: 140, height: 140).opacity(0.6)
            Text("まだ記録がありません").font(Theme.serif(22, .medium)).foregroundStyle(Theme.ink)
            Text("今日の 1 曲を遊ぶと、ここに回数とタイミングのくせがたまっていきます。").font(Theme.text(14)).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button("今日の 1 曲をはじめる") { app.startToday() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 40)
    }

    private var summary: some View {
        let p = app.progress
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Caption("これまで")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(p.totalReps)").font(Theme.serif(64)).kerning(-3).monospacedDigit().foregroundStyle(Theme.ink)
                    Text("回").font(Theme.serif(20)).foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(p.activeDays) 日 ・ \(p.sessions) 曲").font(Theme.text(13, .medium)).foregroundStyle(Theme.ink)
                Text("続けて \(p.streak(today: app.today)) 日").font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var tendency: some View {
        let ms = app.progress.recentOffsetMs() ?? 0
        let t = Tendency.from(ms: ms)
        return Slab {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("最近 10 曲のくせ")
                    Spacer()
                    Text("\(t.label)（\(ms > 0 ? "+" : "")\(ms) ms）").font(Theme.text(13, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                TendencyMeter(ms: ms)
                Text(t.advice).font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Pro の記録の見本（ぼかし）と、Pro の画面への入口
    private var lockedPreview: some View {
        ZStack {
            ProRecords().blur(radius: 6).allowsHitTesting(false).accessibilityHidden(true)
            VStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 16)).foregroundStyle(Theme.ink)
                Text("週の筋肉の偏り・30 日の回数・くせの移り変わり・1 曲ずつの記録は Pro で").font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Button("Pro を見る") { app.sheet = .pro }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 220)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper.opacity(0.92)))
        }
    }
}

/// Pro の記録：30 日の棒・くせの折れ線・1 曲ずつ
private struct ProRecords: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let days = app.progress.repsByDay(last: 30, today: app.today)
        let recent = Array(app.progress.records.suffix(20))
        let points = recent.enumerated().map { OffsetPoint(index: $0.offset, ms: $0.element.meanOffsetMs) }
        VStack(spacing: 16) {
            MuscleWeek()
            Slab {
                VStack(alignment: .leading, spacing: 10) {
                    Caption("この 30 日の回数")
                    Charts.Chart(days, id: \.day) { item in
                        BarMark(x: .value("日", String(item.day.suffix(5))), y: .value("回数", item.reps))
                            .foregroundStyle(Theme.level(item.reps))
                            .cornerRadius(3)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis { AxisMarks(position: .trailing) { _ in AxisValueLabel().font(Theme.label(9)) } }
                    .frame(height: 140)
                }
            }
            Slab {
                VStack(alignment: .leading, spacing: 10) {
                    Caption("くせの移り変わり（ms・0 がちょうど）")
                    Charts.Chart(points) { item in
                        LineMark(x: .value("回", item.index), y: .value("ms", item.ms))
                            .foregroundStyle(Theme.skyDeep)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("回", item.index), y: .value("ms", item.ms))
                            .foregroundStyle(Theme.peachDeep)
                            .symbolSize(24)
                    }
                    .chartXAxis(.hidden)
                    .chartYScale(domain: -150...150)
                    .chartYAxis { AxisMarks(values: [-100, 0, 100]) { _ in
                        AxisGridLine()
                        AxisValueLabel().font(Theme.label(9))
                    } }
                    .frame(height: 120)
                }
            }
            Slab {
                VStack(alignment: .leading, spacing: 10) {
                    Caption("1 曲ずつ（新しい順）")
                    ForEach(recent.reversed()) { r in
                        HStack {
                            Text(String(r.day.suffix(5))).font(Theme.label(11)).monospacedDigit().foregroundStyle(Theme.inkSoft).frame(width: 42, alignment: .leading)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(r.endless ? "エンドレス" : (Songbook.song(r.songID)?.title ?? r.songID)).font(Theme.text(13)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text(r.resolvedTechnique.title).font(Theme.label(10)).foregroundStyle(Theme.inkSoft).lineLimit(1)
                            }
                            Spacer()
                            Text("\(r.reps) 回").font(Theme.text(13, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                            Text(Grade.from(accuracy: r.accuracy).rawValue).font(Theme.serif(16, .medium).italic()).foregroundStyle(Theme.peachDeep).frame(width: 22)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

private struct OffsetPoint: Identifiable {
    let index: Int
    let ms: Int
    var id: Int { index }
}

/// この 7 日の、やり方ごとの回数（無料）
struct WeekTechniques: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let rows = app.progress.weekReps(today: app.today)
        let maxReps = max(1, rows.map(\.reps).max() ?? 1)
        Slab {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("この 7 日のやり方")
                    Spacer()
                    Button("やり方を見る") { app.techniqueFilter = nil; app.sheet = .techniques }
                        .font(Theme.text(12, .medium)).foregroundStyle(Theme.skyDeep)
                }
                if rows.isEmpty {
                    Text("この 7 日はまだ記録がありません。1 曲やると、やり方ごとの回数がここに並びます。")
                        .font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        BodyFigure(technique: row.technique, showPhone: false).frame(width: 44, height: 26)
                        Text(row.technique.title).font(Theme.text(13, .medium)).foregroundStyle(Theme.ink).frame(width: 96, alignment: .leading)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        GeometryReader { geo in
                            Capsule().fill(Theme.level(row.reps))
                                .frame(width: max(6, geo.size.width * CGFloat(row.reps) / CGFloat(maxReps)), height: 8)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(height: 26)
                        Text("\(row.reps) 回").font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// この 7 日の、筋肉ごとの負荷と偏り（Pro）。体の絵の濃さが負荷
struct MuscleWeek: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let load = app.progress.weekLoad(today: app.today)
        let balance = MuscleBalance(load: load)
        let top = max(1, load.values.max() ?? 1)
        // 体の絵：いちばん多い筋肉の 6 割以上を「主に」、それ未満を「補助」の濃さで
        let shade = load.mapValues { $0 / top >= 0.6 ? 1.0 : ($0 > 0 ? 0.5 : 0) }
        Slab {
            VStack(alignment: .leading, spacing: 12) {
                Caption("この 7 日の筋肉")
                HStack(alignment: .center, spacing: 14) {
                    BodyFigure(technique: .standard, load: shade, showPhone: false)
                        .frame(width: 120, height: 68)
                        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.skyMist))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(balance.headline).font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
                        Text(balance.advice).font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(Muscle.allCases) { m in
                    let v = load[m] ?? 0
                    HStack(spacing: 10) {
                        Text(m.label).font(Theme.text(13, .medium)).foregroundStyle(Theme.ink).frame(width: 52, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.skyMist)
                                Capsule().fill(m == balance.top && balance.isLopsided ? Theme.peach : Theme.sky)
                                    .frame(width: max(4, geo.size.width * CGFloat(v / top)))
                            }
                            .frame(height: 8)
                            .frame(maxHeight: .infinity)
                        }
                        .frame(height: 20)
                        Text("\(Int(v.rounded()))").font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(m.label) \(Int(v.rounded()))")
                }
                Text("数は「回数 × 効き方」（主に効く所は 1、補助は 0.5）の目安です。")
                    .font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}
