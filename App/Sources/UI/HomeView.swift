import SwiftUI

/// ホーム：今日の 1 曲（はじめるボタンはスクロールせずに見える）・30 日の道・積み上げ
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                topBar
                if hSize == .regular {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 18) { TodayHero(); PathStrip() }
                        VStack(spacing: 18) { StatsStrip(); WeekBars(); menu }
                            .frame(width: 320)
                    }
                } else {
                    TodayHero()
                    PathStrip()
                    StatsStrip()
                    WeekBars()
                    menu
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.ground.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Caption("Push Beat")
                Text("うでたてビート").font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
            }
            Spacer()
            if !app.isPro {
                Button { app.sheet = .pro } label: {
                    Text("Pro").font(Theme.text(13, .semibold)).foregroundStyle(Theme.peachDeep)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(Capsule().fill(Theme.peachSoft))
                }
                .accessibilityLabel("Pro について")
            }
            Button { app.sheet = .settings } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.paper))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            }
            .accessibilityLabel("設定")
        }
    }

    private var menu: some View {
        HStack(spacing: 10) {
            menuButton("opticaldisc", "曲をえらぶ") { app.sheet = .songs }
            menuButton("infinity", "フリー") { app.startEndless(song: Songbook.song(app.todayPlan.songID) ?? Songbook.all[0]) }
            menuButton("chart.bar", "記録") { app.sheet = .records }
        }
    }

    private func menuButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(Theme.skyDeep)
                Text(title).font(Theme.text(13, .medium)).foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
        }
        .buttonStyle(.plain)
    }
}

/// 今日の 1 曲：マットの上のレコードと、大きな回数
private struct TodayHero: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let plan = app.todayPlan
        let done = app.progress.planDoneToday(app.course, today: app.today)
        let complete = app.progress.isCourseComplete(app.course) && !done
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                RecordDisc(label: plan.song.title, angle: .degrees(-20)).frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 4) {
                    Caption("Day \(plan.day) / \(Program.length) ・ \(plan.style)", color: Theme.skyDeep)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(done ? "できた" : "今日は").font(Theme.serif(17)).foregroundStyle(Theme.inkSoft)
                        Text("\(plan.reps)").font(Theme.serif(54)).kerning(-3).monospacedDigit().foregroundStyle(Theme.ink)
                        Text("回").font(Theme.serif(18)).foregroundStyle(Theme.inkSoft)
                    }
                    Text("\(plan.song.title) ・ BPM \(Int(plan.song.bpm))").font(Theme.text(13)).foregroundStyle(Theme.ink)
                    LevelDots(level: plan.song.level)
                }
            }
            Text(complete ? "30 日をやりきりました。設定でコースを変えるか、好きな曲で続けよう" : plan.tip)
                .font(Theme.text(13)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(done ? "もう一回やる" : "はじめる") { app.startToday() }
                .buttonStyle(PrimaryButtonStyle(fill: done ? Theme.sky : Theme.skyDeep))
        }
        .padding(18)
        .background(YogaMat(corner: 24))
        .overlay(alignment: .topTrailing) {
            if done {
                Label("今日の分", systemImage: "checkmark").font(Theme.text(12, .semibold)).foregroundStyle(Theme.skyDeep)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.paper))
                    .padding(12)
            }
        }
    }
}

/// 30 日の道（Duolingo の「1 本の道」を借りた）。今日のマスが peach の輪
private struct PathStrip: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let course = app.course
        let next = app.progress.nextDay[course] ?? 1
        let todayDay = app.todayPlan.day
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Caption(course.title)
                Spacer()
                Text("\(min(next - 1, Program.length)) / \(Program.length) 日").font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.inkSoft)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.line).frame(height: 2).padding(.horizontal, 16)
                        HStack(spacing: 14) {
                            ForEach(Program.days(course), id: \.day) { d in
                                node(d, done: d.day < next, isToday: d.day == todayDay)
                                    .id(d.day)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 6)
                }
                .onAppear { proxy.scrollTo(todayDay, anchor: .center) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }

    private func node(_ d: PlanDay, done: Bool, isToday: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(done ? Theme.skyDeep : (d.isLight ? Theme.skyMist : Theme.paper))
                Circle().stroke(isToday ? Theme.peachDeep : (done ? Theme.skyDeep : Theme.line), lineWidth: isToday ? 2.5 : 1)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                } else {
                    Text("\(d.reps)").font(Theme.serif(13, .medium)).monospacedDigit().foregroundStyle(isToday ? Theme.peachDeep : Theme.inkSoft)
                }
            }
            .frame(width: isToday ? 40 : 32, height: isToday ? 40 : 32)
            Text("\(d.day)").font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement()
        .accessibilityLabel("\(d.day) 日目 \(d.reps) 回\(done ? " できた" : "")\(isToday ? " 今日" : "")")
    }
}

/// 積み上げ：これまでの回数・続けた日・フリーの自己ベスト
private struct StatsStrip: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let p = app.progress
        let streak = p.streak(today: app.today)
        HStack(spacing: 0) {
            stat("\(p.totalReps)", "これまでの回数")
            divider
            stat("\(streak)", streak > 0 ? "続けた日" : (p.activeDays > 0 ? "おかえり。合計 \(p.activeDays) 日" : "続けた日"))
            divider
            stat("\(p.bestEndless)", "フリーの最高")
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(width: 1, height: 36) }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.serif(28)).kerning(-1).monospacedDigit().foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label).font(Theme.label(10)).foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// この 7 日の回数（棒の濃さは回数の段階）
struct WeekBars: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let days = app.progress.repsByDay(last: 7, today: app.today)
        let maxReps = max(10, days.map(\.reps).max() ?? 10)
        VStack(alignment: .leading, spacing: 10) {
            Caption("この 7 日")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.day) { item in
                    VStack(spacing: 4) {
                        Text(item.reps > 0 ? "\(item.reps)" : "").font(Theme.label(10)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.level(item.reps))
                            .frame(height: max(4, 64 * CGFloat(item.reps) / CGFloat(maxReps)))
                        Text(String(item.day.suffix(2))).font(Theme.label(10)).monospacedDigit()
                            .foregroundStyle(item.day == app.today ? Theme.peachDeep : Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
        .accessibilityElement()
        .accessibilityLabel("この 7 日の回数 " + days.map { "\($0.reps)" }.joined(separator: "、"))
    }
}
