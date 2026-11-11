import SwiftUI

/// ホーム：今日のコースとエンドレスが同じ大きさで並ぶ（はじめるボタンはスクロールせずに見える）・筋肉の入口・30 日の道・積み上げ
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                topBar
                if app.progress.baseline == nil { BaselinePrompt() }
                if hSize == .regular {
                    HStack(alignment: .top, spacing: 18) {
                        TodayHero()
                        EndlessCard()
                    }
                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 18) { MuscleEntry(); PathStrip() }
                        VStack(spacing: 18) { StatsStrip(); WeekBars(); menu }
                            .frame(width: 320)
                    }
                } else {
                    TodayHero()
                    EndlessCard()
                    MuscleEntry()
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
                Text(L("うでたてビート")).font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
            }
            Spacer()
            if !app.isPro {
                Button { app.sheet = .pro } label: {
                    Text("Pro").font(Theme.text(13, .semibold)).foregroundStyle(Theme.peachDeep)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(Capsule().fill(Theme.peachSoft))
                }
                .accessibilityLabel(L("Pro について"))
            }
            Button { app.sheet = .settings } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.paper))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            }
            .accessibilityLabel(L("設定"))
        }
    }

    private var menu: some View {
        HStack(spacing: 10) {
            menuButton("opticaldisc", L("曲をえらぶ")) { app.sheet = .songs }
            menuButton("figure.strengthtraining.functional", L("やり方")) { app.techniqueFilter = nil; app.sheet = .techniques }
            menuButton("chart.bar", L("記録")) { app.sheet = .records }
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

/// 今日のコース：マットの上のレコードと、大きな回数（−／＋ でいつでも変えられる）と、今日のやり方
private struct TodayHero: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let plan = app.todayPlan
        let technique = app.todayTechnique
        let done = app.progress.planDoneToday(app.course, today: app.today)
        let complete = app.progress.isCourseComplete(app.course) && !done
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                RecordDisc(label: plan.song.title, angle: .degrees(-20)).frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Caption(L("今日のコース ・ Day %@ / %@", "\(plan.day)", "\(Program.length)"), color: Theme.skyDeep)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(done ? L("できた") : L("今日は")).font(Theme.serif(16)).foregroundStyle(Theme.inkSoft)
                        Text("\(plan.reps)").font(Theme.serif(52)).kerning(-3).monospacedDigit().foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text(L("回")).font(Theme.serif(18)).foregroundStyle(Theme.inkSoft)
                    }
                    Text(L("%@ ・ BPM %@", "\(plan.song.title)", "\(Int(technique.bpm(for: plan.song)))")).font(Theme.text(13)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            RepsAdjuster()
            Button { app.techniqueFilter = nil; app.sheet = .techniques } label: {
                HStack(spacing: 10) {
                    BodyFigure(technique: technique, showPhone: false).frame(width: 64, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("やり方：%@", "\(technique.title)")).font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                        Text(L("主に") + technique.mainMuscles.map(\.label).joined(separator: L("・")))
                            .font(Theme.text(11)).foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    Text(L("かえる")).font(Theme.text(12, .medium)).foregroundStyle(Theme.skyDeep)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.paper.opacity(0.85)))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(L("今日のやり方 %@。かえる", "\(technique.title)"))
            Text(complete ? L("30 日をやりきりました。設定でコースを変えるか、エンドレスで続けよう") : plan.tip)
                .font(Theme.text(13)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(done ? L("もう一回やる") : L("はじめる")) { app.startToday() }
                .buttonStyle(PrimaryButtonStyle(fill: done ? Theme.sky : Theme.skyDeep))
        }
        .padding(18)
        .background(YogaMat(corner: 24))
        .overlay(alignment: .topTrailing) {
            if done {
                Label(L("今日の分"), systemImage: "checkmark").font(Theme.text(12, .semibold)).foregroundStyle(Theme.skyDeep)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.paper))
                    .padding(12)
            }
        }
    }
}

/// 今日の回数の −／＋（これからの日にも続く。いまの自分の回数への入口）
private struct RepsAdjuster: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let shift = app.progress.repShift
        HStack(spacing: 8) {
            step("minus", -1)
            VStack(alignment: .leading, spacing: 1) {
                Text(shift == 0 ? L("回数を調整") : L("いつもより %@%@ 回", "\(shift > 0 ? "+" : "")", "\(shift)"))
                    .font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                Button {
                    app.sheet = .baseline
                } label: {
                    Text(app.progress.baseline.map { L("いまの自分 %@ 回 ・ 変える", "\($0)") } ?? L("いまの自分の回数を決める"))
                        .font(Theme.text(11)).foregroundStyle(Theme.skyDeep)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if shift != 0 {
                Button(L("もとに戻す")) { withAnimation(.easeOut(duration: 0.2)) { app.progress.repShift = 0 }; Feedback.select() }
                    .font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
            }
            step("plus", 1)
        }
    }

    private func step(_ icon: String, _ delta: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { app.nudgeReps(delta) }
        } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                .frame(width: 40, height: 36)
                .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.paper))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(delta > 0 ? L("今日の回数を 1 回ふやす") : L("今日の回数を 1 回へらす"))
    }
}

/// エンドレス：今日のコースと並ぶ、もう 1 つの主役。自己ベスト 3 つと、ベストまでの差
private struct EndlessCard: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let best = app.progress.endlessBest
        let technique = app.todayTechnique
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RecordDisc(label: "", angle: .degrees(30)).frame(width: 96, height: 96)
                    Image(systemName: "infinity").font(.system(size: 20, weight: .medium)).foregroundStyle(Theme.ink)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Caption("Endless", color: Theme.peachDeep)
                    Text(L("エンドレス")).font(Theme.serif(30, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
                    Text(L("3 回続けて外すまで、どこまでも")).font(Theme.text(13)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                stat("\(best.reps)", L("最高の回数"))
                divider
                stat("\(best.combo)", L("最大コンボ"))
                divider
                stat(EndlessCard.time(best.seconds), L("続いた時間"))
            }
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.paper.opacity(0.9)))
            Text(best.reps > 0 ? L("%@ 回で自己ベスト更新。やり方は今日と同じ%@", "\(best.reps + 1)", "\(technique.title)") : L("まずは 1 回。続いた回数・コンボ・時間がベストとして残ります"))
                .font(Theme.text(13)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(L("エンドレスをはじめる")) { app.startEndlessToday() }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.peachDeep))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.peachSoft.opacity(0.55)))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(width: 1, height: 30) }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(Theme.serif(22, .medium)).kerning(-0.5).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.label(10)).foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// 秒を「1:05」の形に
    static func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}

/// いまの自分の回数がまだ決まっていないときの案内（決めると、30 日の道がその人の回数になる）
private struct BaselinePrompt: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Button { app.sheet = .baseline } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.below.square.filled.and.square").font(.system(size: 18)).foregroundStyle(Theme.skyDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("回数を、自分に合わせる")).font(Theme.text(14, .semibold)).foregroundStyle(Theme.ink)
                    Text(L("休まず何回できるかを決めると、30 日の回数があなたに合わせて変わります"))
                        .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.skyDeep.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// 筋肉から選ぶ入口：「今日は胸の日」
private struct MuscleEntry: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Caption(L("筋肉から選ぶ"))
                Spacer()
                Text(L("8 つのやり方")).font(Theme.text(12, .medium)).foregroundStyle(Theme.inkSoft)
            }
            MuscleGrid(selected: nil, compact: true) { m in
                app.techniqueFilter = m
                app.sheet = .techniques
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.line, lineWidth: Theme.hairline))
    }
}

/// 30 日の道（Duolingo の「1 本の道」を借りた）。今日のマスが peach の輪
private struct PathStrip: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let course = app.course
        let next = app.progress.nextDay[course] ?? 1
        let todayDay = app.todayPlan.day
        let days = app.progress.planDays(course)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Caption(course.title)
                Spacer()
                Text(L("%@ / %@ 日", "\(min(next - 1, Program.length))", "\(Program.length)")).font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.inkSoft)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.line).frame(height: 2).padding(.horizontal, 16)
                        HStack(spacing: 14) {
                            ForEach(days, id: \.day) { d in
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
        .accessibilityLabel(L("%@ 日目 %@ 回%@%@", "\(d.day)", "\(d.reps)", "\(done ? L(" できた") : "")", "\(isToday ? L(" 今日") : "")"))
    }
}

/// 積み上げ：これまでの回数・続けた日・今週いちばん使った筋肉
private struct StatsStrip: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let p = app.progress
        let streak = p.streak(today: app.today)
        HStack(spacing: 0) {
            stat("\(p.totalReps)", L("これまでの回数"))
            divider
            stat("\(streak)", streak > 0 ? L("続けた日") : (p.activeDays > 0 ? L("おかえり。合計 %@ 日", "\(p.activeDays)") : L("続けた日")))
            divider
            let balance = MuscleBalance(load: p.weekLoad(today: app.today))
            stat(balance.top?.label ?? "-", L("今週いちばん"))
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
            Caption(L("この 7 日"))
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
        .accessibilityLabel(L("この 7 日の回数 ") + days.map { "\($0.reps)" }.joined(separator: L("、")))
    }
}
