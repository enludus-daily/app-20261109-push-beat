import SwiftUI

/// やり方 × 筋肉のメニュー：筋肉から選ぶ入口（今日は胸の日）と、8 つのやり方
struct TechniquesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("今日はどこに効かせる？").font(Theme.serif(24, .medium)).foregroundStyle(Theme.ink)
                    MuscleGrid(selected: app.techniqueFilter) { m in
                        withAnimation(.easeOut(duration: 0.25)) { app.techniqueFilter = app.techniqueFilter == m ? nil : m }
                        Feedback.select()
                    }
                    HStack {
                        Caption(app.techniqueFilter.map { "\($0.dayTitle)のやり方" } ?? "8 つのやり方")
                        Spacer()
                        if app.techniqueFilter != nil {
                            Button("すべて見る") { withAnimation(.easeOut(duration: 0.25)) { app.techniqueFilter = nil } }
                                .font(Theme.text(12, .medium)).foregroundStyle(Theme.skyDeep)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: hSize == .regular ? 2 : 1), spacing: 14) {
                        ForEach(list) { t in
                            TechniqueCard(technique: t, focus: app.techniqueFilter) {
                                app.pickTechnique(t)
                                dismiss()
                            }
                        }
                    }
                    Text("効く所は、一般的なフォームで主に使われる筋肉の目安です。痛みがあるときは休んでください。")
                        .font(Theme.text(11)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("やり方と筋肉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private var list: [Technique] {
        guard let m = app.techniqueFilter else { return Technique.allCases }
        return Technique.targeting(m)
    }
}

/// 筋肉の入口（2×2。体の絵の、その筋肉だけに色）
struct MuscleGrid: View {
    var selected: Muscle?
    var compact = false
    let onSelect: (Muscle) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: compact ? 4 : 2), spacing: 10) {
            ForEach(Muscle.allCases) { m in
                Button { onSelect(m) } label: {
                    VStack(alignment: compact ? .center : .leading, spacing: compact ? 2 : 6) {
                        BodyFigure(technique: Self.pose(for: m), focus: m, showPhone: false)
                            .frame(height: compact ? 34 : 52)
                        if compact {
                            Text(m.label).font(Theme.text(12, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                Text(m.dayTitle).font(Theme.serif(17, .medium)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(Technique.targeting(m).count) つ").font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
                            }
                        }
                    }
                    .padding(compact ? 8 : 12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(selected == m ? Theme.peachSoft : Theme.paper))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous)
                        .stroke(selected == m ? Theme.peachDeep : Theme.line, lineWidth: selected == m ? 1.2 : Theme.hairline))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(m.dayTitle)
                .accessibilityAddTraits(selected == m ? .isSelected : [])
            }
        }
    }

    /// 筋肉ごとの見本の姿勢
    static func pose(for m: Muscle) -> Technique {
        switch m {
        case .chest: .wide
        case .triceps: .diamond
        case .shoulder: .pike
        case .core: .hold
        }
    }
}

/// やり方の 1 枚：体の絵・効く所・譜面の性格・フォームの要点・選ぶボタン
struct TechniqueCard: View {
    @Environment(AppModel.self) private var app
    let technique: Technique
    var focus: Muscle?
    let onPick: () -> Void

    var body: some View {
        let t = technique
        let picked = app.todayTechnique == t
        let locked = t.isPro && !app.isPro
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                BodyFigure(technique: t)
                    .frame(width: 128, height: 72)
                    .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(Theme.skyMist))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Caption(t.english)
                        if locked {
                            Text("Pro").font(Theme.label(10)).foregroundStyle(Theme.peachDeep)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Capsule().fill(Theme.peachSoft))
                        }
                    }
                    Text(t.title).font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
                    LevelDots(level: t.level)
                    MuscleTags(technique: t, focus: focus)
                }
                Spacer(minLength: 0)
            }
            Text(t.rhythmLine).font(Theme.text(12, .medium)).foregroundStyle(Theme.skyDeep)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(t.form, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle().fill(Theme.sky).frame(width: 4, height: 4).offset(y: -2)
                        Text(line).font(Theme.text(13)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button(action: onPick) {
                HStack(spacing: 6) {
                    if picked { Image(systemName: "checkmark") }
                    Text(buttonTitle(picked: picked, locked: locked))
                }
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(locked && !app.canUse(t))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous)
            .stroke(picked ? Theme.skyDeep : Theme.line, lineWidth: picked ? 1.2 : Theme.hairline))
        .overlay(alignment: .bottom) {
            if locked && !app.canUse(t) {
                Button("Pro で使える") { app.sheet = .pro }
                    .buttonStyle(PrimaryButtonStyle(fill: Theme.peachDeep))
                    .padding(14)
            }
        }
    }

    private func buttonTitle(picked: Bool, locked: Bool) -> String {
        if picked { return "今日のやり方" }
        if locked { return "1 回だけ試す（今日のやり方にする）" }
        return "今日はこれにする"
    }
}

/// 効く所の札（主に＝peach、補助＝線だけ）
struct MuscleTags: View {
    let technique: Technique
    var focus: Muscle?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(technique.mainMuscles) { m in
                Text(m.label).font(Theme.label(10)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(m == focus ? Theme.peach : Theme.peachSoft))
            }
            ForEach(technique.subMuscles) { m in
                Text(m.label).font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
        }
        .lineLimit(1)
        .accessibilityElement()
        .accessibilityLabel("主に" + technique.mainMuscles.map(\.label).joined(separator: "・"))
    }
}

/// 押すと少し沈む（0.97 倍）
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// いまの自分の回数を決める：数を選ぶか、エンドレスでためす。30 日の道の見本がその場で変わる
struct BaselineView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var value = 10

    private let quick = [3, 5, 10, 15, 20, 30, 40, 50]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("いまの自分は、\n休まず何回できる？").font(Theme.serif(26, .medium)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("ふつうの腕立てで、フォームを崩さずに続けられる回数。ひざをついてやっとなら 3〜5 回で。")
                            .font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 18) {
                        stepButton("minus", -1)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value)").font(Theme.serif(72)).kerning(-3).monospacedDigit().foregroundStyle(Theme.ink)
                                .contentTransition(.numericText())
                            Text("回").font(Theme.serif(20)).foregroundStyle(Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        stepButton("plus", 1)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(quick, id: \.self) { n in
                            Button { withAnimation(.easeOut(duration: 0.2)) { value = n }; Feedback.select() } label: {
                                Text(n == 3 ? "3 以下" : (n == 50 ? "50+" : "\(n)"))
                                    .font(Theme.serif(17, .medium)).monospacedDigit()
                                    .foregroundStyle(value == n ? .white : Theme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(value == n ? Theme.skyDeep : Theme.skyMist))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    PlanPreview(baseline: value, course: app.course)
                    Button("この回数で 30 日の道を作る") {
                        app.useAsBaseline(value)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("ためして決める（エンドレスで数える）") { app.startMeasure() }
                        .buttonStyle(QuietButtonStyle())
                    Text("あとから設定でいつでも変えられます。毎回の結果で、次の回数を少し上げ下げする提案も出ます。")
                        .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("いまの自分の回数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear { value = app.progress.baseline ?? 10 }
    }

    private func stepButton(_ icon: String, _ delta: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { value = min(150, max(1, value + delta)) }
            Feedback.select()
        } label: {
            Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.ink)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.paper))
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(delta > 0 ? "1 回ふやす" : "1 回へらす")
    }
}

/// 30 日の道の見本（棒 30 本と、はじめと終わりの回数）
struct PlanPreview: View {
    let baseline: Int
    let course: Course

    var body: some View {
        let days = Program.days(course, baseline: baseline)
        let maxReps = max(1, days.map(\.reps).max() ?? 1)
        Slab {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Caption(course.title)
                    Spacer()
                    Text("Day 1 は \(days[0].reps) 回 → Day 30 は \(days[29].reps) 回")
                        .font(Theme.text(12, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(days, id: \.day) { d in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(d.isLight ? Theme.skySoft : Theme.level(d.reps))
                            .frame(height: max(3, 56 * CGFloat(d.reps) / CGFloat(maxReps)))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 56, alignment: .bottom)
                .animation(.easeOut(duration: 0.25), value: baseline)
                Text("7 日ごとに軽い日。はじめは今の 6 割から、少しずつ増えます。")
                    .font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("1 日目 \(days[0].reps) 回から 30 日目 \(days[29].reps) 回まで")
    }
}
