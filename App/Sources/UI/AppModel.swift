import SwiftUI
import UIKit

enum Route: Equatable {
    case home, play, result
}

enum Sheet: String, Identifiable {
    case songs, records, settings, pro, techniques, baseline
    var id: String { rawValue }
}

/// 何を遊ぶか
struct PlayRequest: Equatable {
    let song: Song
    let reps: Int
    var technique: Technique = .standard
    var plan: PlanDay?
    var endless = false
    /// 指でためす練習（記録しない）
    var practice = false
    /// いまの自分の回数をためす（エンドレスで数え、結果の画面で道に使える）
    var measure = false
}

/// アプリ全体の状態：進み具合（端末に保存）・課金・いまの画面
@MainActor
@Observable
final class AppModel {
    private static let key = "progress.v1"

    var progress: Progress { didSet { save() } }
    var route: Route = .home
    var sheet: Sheet?
    var game: GameModel?
    /// 遊び終わった結果（結果の画面）
    var lastResult: ResultSummary?
    let store: PurchaseStore
    private let defaults: UserDefaults
    /// 撮影のときは保存しない
    private var persist = true

    var isPro: Bool { store.entitlements.isPro }
    var today: String { DayKey.key(Date()) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.001"
        let pro = ProductID.pro(bundleID: bundleID)
        store = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        if let data = defaults.data(forKey: Self.key), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
    }

    private func save() {
        guard persist, let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func onLaunch() async {
        await store.load()
        if progress.settings.course == .advanced, !isPro { progress.settings.course = .starter }
    }

    // MARK: 遊ぶ

    var course: Course { isPro ? progress.settings.course : .starter }
    var todayPlan: PlanDay { progress.plan(course, today: today) }
    /// 今日のやり方（ホームで選んだもの、なければ道の日のやり方）
    var todayTechnique: Technique {
        let t = progress.technique(for: todayPlan, today: today)
        // お試しを使い終えた Pro のやり方は、道の日のやり方に戻す（今日の分が止まらないように）
        return canUse(t) ? t : todayPlan.technique
    }
    /// やり方の画面で、筋肉から絞りこんでいるとき
    var techniqueFilter: Muscle?

    func canPlay(_ song: Song) -> Bool { !song.isPro || isPro || !progress.usedProTrial }
    func canUse(_ t: Technique) -> Bool { !t.isPro || isPro || !progress.usedTechniqueTrial }
    /// Pro のやり方を、お試しの 1 回で使うことになるか
    func isTrial(_ t: Technique) -> Bool { t.isPro && !isPro && !progress.usedTechniqueTrial }

    func start(_ request: PlayRequest) {
        let proSong = request.song.isPro && !isPro
        let proTechnique = request.technique.isPro && !isPro
        if (proSong && progress.usedProTrial) || (proTechnique && progress.usedTechniqueTrial) {
            sheet = .pro
            return
        }
        if proSong { progress.usedProTrial = true }
        if proTechnique { progress.usedTechniqueTrial = true }
        sheet = nil
        game = GameModel(request: request, settings: progress.settings)
        lastResult = nil
        route = .play
    }

    func startToday() {
        let plan = todayPlan
        start(PlayRequest(song: plan.song, reps: plan.reps, technique: todayTechnique, plan: plan))
    }

    /// 今日のやり方を選ぶ（その日だけ。道の日のやり方に戻すなら nil にする）
    func pickTechnique(_ t: Technique) {
        progress.techniquePick = t == todayPlan.technique ? nil : TechniquePick(day: today, technique: t)
        Feedback.select()
    }

    /// 今日の回数を −／＋（これからの日にも続く）
    func nudgeReps(_ delta: Int) {
        progress.nudge(delta, course: course, today: today)
        Feedback.select()
    }

    /// いまの自分の回数を、エンドレスで数えてためす（ふつうの腕立て。3 回続けて外すか、やめるまで）
    func startMeasure() {
        start(PlayRequest(song: Songbook.all[0], reps: 300, technique: .standard, endless: true, measure: true))
    }

    /// はじめの案内から、指で 4 回だけためす
    func startPractice() {
        progress.hasOnboarded = true
        start(PlayRequest(song: Songbook.all[0], reps: 4, practice: true))
    }

    func startEndless(song: Song, technique: Technique? = nil) {
        start(PlayRequest(song: song, reps: 300, technique: technique ?? todayTechnique, endless: true))
    }

    /// ホームのエンドレス：今日の曲と、今日のやり方で
    func startEndlessToday() {
        startEndless(song: todayPlan.song)
    }

    /// 結果の提案を受け入れる（次の日から回数が変わる）
    func acceptAdvice(_ advice: RepAdvice) {
        progress.repShift += advice.delta
        Feedback.select()
    }

    /// ためした回数で、30 日の道を作る
    func useAsBaseline(_ reps: Int) {
        progress.setBaseline(reps)
        Feedback.finished()
    }

    /// GameModel が終わったときに呼ぶ
    func finish(_ g: GameModel) {
        let s = g.session
        let c = s.count
        let quit = s.endedEarly
        // 1 回も触れずにやめたら、記録しないでホームへ
        if quit, s.reps == 0 { return goHome() }
        let record = SessionRecord(day: today, index: progress.nextIndex(on: today), songID: g.request.song.id, reps: s.reps,
                                   perfect: c.perfect, good: c.good, miss: c.miss, maxCombo: s.maxCombo, score: s.score,
                                   meanOffsetMs: s.meanOffsetMs, course: quit ? nil : g.request.plan?.course,
                                   planDay: quit ? nil : g.request.plan?.day, endless: g.request.endless,
                                   technique: g.request.technique, seconds: g.seconds)
        if g.request.practice {
            lastResult = ResultSummary(record: record, song: g.request.song, plan: nil, clearedPlan: false, newBest: false,
                                       streak: progress.streak(today: today), totalReps: progress.totalReps, quit: quit, practice: true)
            game = nil
            route = .result
            return
        }
        let before = progress.endlessBest
        let wasBest = g.request.endless && s.reps > progress.bestEndless
        let advanced = progress.record(record, today: today)
        var summary = ResultSummary(record: record, song: g.request.song, plan: g.request.plan, clearedPlan: advanced,
                                    newBest: wasBest, streak: progress.streak(today: today), totalReps: progress.totalReps,
                                    quit: quit, practice: false)
        summary.endlessBefore = g.request.endless ? before : nil
        summary.measure = g.request.measure
        if g.request.plan != nil, !g.request.endless {
            let advice = RepAdvice.suggest(reps: g.request.reps, perfect: c.perfect, good: c.good, miss: c.miss, finished: !quit)
            summary.advice = advice
            let next = progress.upcomingPlan(course)
            summary.nextReps = next.reps
            summary.nextRepsAfter = Program.day(next.course, next.day, baseline: progress.baseline, shift: progress.repShift + advice.delta).reps
            summary.nextDay = next.day
        }
        lastResult = summary
        game = nil
        route = .result
    }

    /// 価値を感じた直後（2 回目に遊び終えたとき）に 1 回だけ Pro を見せる
    func maybeShowProAfterResult() {
        guard !isPro, !progress.hasSeenPaywall, progress.sessions >= 2, lastResult?.practice != true else { return }
        progress.hasSeenPaywall = true
        sheet = .pro
    }

    func replay() {
        guard let r = lastResult else { return route = .home }
        let technique = r.record.resolvedTechnique
        if r.measure { startMeasure() } else if r.record.endless { startEndless(song: r.song, technique: technique) } else {
            start(PlayRequest(song: r.song, reps: r.plan?.reps ?? r.record.perfect + r.record.good + r.record.miss,
                              technique: technique, plan: r.plan))
        }
    }

    func goHome() {
        game = nil
        route = .home
    }

    // MARK: 撮影用（CI のスクリーンショット。起動引数 -screenshotScene <名前>）

    func applyScreenshotScene(_ name: String) {
        // 「-en」で終わる名前は英語で撮る（Localization.bundle）。開く画面は同じ
        let scene = name.hasSuffix("-en") ? String(name.dropLast(3)) : name
        persist = false
        progress = Self.sampleProgress(today: today)
        switch scene {
        case "home": break
        case "endless":
            let plan = progress.plan(.starter, today: today)
            game = GameModel(request: PlayRequest(song: plan.song, reps: 300, technique: .wide, endless: true), settings: progress.settings)
            game?.freezeForScreenshot(hits: 19)
            route = .play
        case "endless-result":
            let plan = progress.plan(.starter, today: today)
            let g = GameModel(request: PlayRequest(song: plan.song, reps: 300, technique: .standard, endless: true),
                              settings: progress.settings)
            g.simulateEndless(hits: 27)
            finish(g)
        case "techniques": sheet = .techniques
        case "baseline": sheet = .baseline
        case "play":
            let plan = progress.plan(.starter, today: today)
            game = GameModel(request: PlayRequest(song: plan.song, reps: plan.reps, technique: plan.technique, plan: plan),
                             settings: progress.settings)
            game?.freezeForScreenshot(hits: 7)
            route = .play
        case "result":
            let plan = progress.plan(.starter, today: today)
            let g = GameModel(request: PlayRequest(song: plan.song, reps: plan.reps, technique: plan.technique, plan: plan),
                              settings: progress.settings)
            g.simulateWholeSong()
            finish(g)
        case "songs": sheet = .songs
        case "records": sheet = .records
        case "settings": sheet = .settings
        case "pro": sheet = .pro
        case "onboarding": progress.hasOnboarded = false
        default: break
        }
    }

    /// 見本のデータ：12 日続けて、今日は 13 日目。いまの自分の回数は 12 回
    static func sampleProgress(today: String) -> Progress {
        var p = Progress()
        p.hasOnboarded = true
        p.hasSeenPaywall = true
        p.baseline = 12
        guard let t = DayKey.ordinal(today) else { return p }
        let offsets = [-62, -48, -35, -40, -22, -18, -9, 4, -12, 6, 10, -5]
        for d in 0..<12 {
            let plan = p.planDay(.starter, d + 1)
            let day = DayKey.key(ordinal: t - 12 + d)
            let miss = d < 4 ? 2 : (d < 8 ? 1 : 0)
            let good = max(0, plan.reps / 4 - d / 4)
            let r = SessionRecord(day: day, index: 0, songID: plan.songID, reps: plan.reps, perfect: plan.reps - good - miss, good: good,
                                  miss: miss, maxCombo: plan.reps - miss * 2, score: plan.reps * 110, meanOffsetMs: offsets[d],
                                  course: .starter, planDay: d + 1, endless: false, technique: plan.technique, seconds: plan.reps * 3)
            p.record(r, today: day)
        }
        // この週のエンドレス（ワイド）を 2 回
        for (back, reps, combo) in [(3, 18, 14), (1, 24, 21)] {
            let r = SessionRecord(day: DayKey.key(ordinal: t - back), index: 1, songID: "sunset-walk", reps: reps, perfect: reps - 4, good: 2,
                                  miss: 3, maxCombo: combo, score: reps * 100, meanOffsetMs: -8, course: nil, planDay: nil, endless: true,
                                  technique: .wide, seconds: reps * 3 + 6)
            p.record(r, today: r.day)
        }
        return p
    }
}

/// 結果の画面に出すもの
struct ResultSummary: Equatable {
    let record: SessionRecord
    let song: Song
    let plan: PlanDay?
    let clearedPlan: Bool
    let newBest: Bool
    let streak: Int
    let totalReps: Int
    let quit: Bool
    let practice: Bool
    /// エンドレスのとき、この回の前の自己ベスト
    var endlessBefore: EndlessBest?
    /// いまの自分の回数をためした回
    var measure = false
    /// 今日の道の回のとき：次の回数の提案と、受け入れる前と後の回数
    var advice: RepAdvice = .keep
    var nextReps = 0
    var nextRepsAfter = 0
    var nextDay = 0

    var grade: Grade { Grade.from(accuracy: record.accuracy) }
    var tendency: Tendency { Tendency.from(ms: record.meanOffsetMs) }
}
