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
                Text("30 日の回数・くせの移り変わり・1 曲ずつの記録は Pro で").font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
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
                            Text(Songbook.song(r.songID)?.title ?? r.songID).font(Theme.text(13)).foregroundStyle(Theme.ink).lineLimit(1)
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
