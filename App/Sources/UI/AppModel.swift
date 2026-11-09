import SwiftUI
import UIKit

enum Route: Equatable {
    case home, play, result
}

enum Sheet: String, Identifiable {
    case songs, records, settings, pro
    var id: String { rawValue }
}

/// 何を遊ぶか
struct PlayRequest: Equatable {
    let song: Song
    let reps: Int
    var plan: PlanDay?
    var endless = false
    var isTrial = false
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

    func canPlay(_ song: Song) -> Bool { !song.isPro || isPro || !progress.usedProTrial }

    func start(_ request: PlayRequest) {
        if request.song.isPro, !isPro {
            guard !progress.usedProTrial else { sheet = .pro; return }
            progress.usedProTrial = true
        }
        sheet = nil
        game = GameModel(request: request, settings: progress.settings)
        lastResult = nil
        route = .play
    }

    func startToday() {
        let plan = todayPlan
        start(PlayRequest(song: plan.song, reps: plan.reps, plan: plan))
    }

    func startEndless(song: Song) {
        start(PlayRequest(song: song, reps: 300, endless: true))
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
                                   planDay: quit ? nil : g.request.plan?.day, endless: g.request.endless)
        let wasBest = g.request.endless && s.reps > progress.bestEndless
        let advanced = progress.record(record, today: today)
        lastResult = ResultSummary(record: record, song: g.request.song, plan: g.request.plan, clearedPlan: advanced,
                                   newBest: wasBest, streak: progress.streak(today: today), totalReps: progress.totalReps,
                                   quit: quit)
        game = nil
        route = .result
    }

    /// 価値を感じた直後（2 回目に遊び終えたとき）に 1 回だけ Pro を見せる
    func maybeShowProAfterResult() {
        guard !isPro, !progress.hasSeenPaywall, progress.sessions >= 2 else { return }
        progress.hasSeenPaywall = true
        sheet = .pro
    }

    func replay() {
        guard let r = lastResult else { return route = .home }
        if r.record.endless { startEndless(song: r.song) } else {
            start(PlayRequest(song: r.song, reps: r.plan?.reps ?? r.record.perfect + r.record.good + r.record.miss, plan: r.plan))
        }
    }

    func goHome() {
        game = nil
        route = .home
    }

    // MARK: 撮影用（CI のスクリーンショット。起動引数 -screenshotScene <名前>）

    func applyScreenshotScene(_ scene: String) {
        persist = false
        progress = Self.sampleProgress(today: today)
        switch scene {
        case "home": break
        case "play":
            let plan = progress.plan(.starter, today: today)
            game = GameModel(request: PlayRequest(song: plan.song, reps: plan.reps, plan: plan), settings: progress.settings)
            game?.freezeForScreenshot(hits: 7)
            route = .play
        case "result":
            let plan = progress.plan(.starter, today: today)
            let g = GameModel(request: PlayRequest(song: plan.song, reps: plan.reps, plan: plan), settings: progress.settings)
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

    /// 見本のデータ：12 日続けて、今日は 13 日目
    static func sampleProgress(today: String) -> Progress {
        var p = Progress()
        p.hasOnboarded = true
        p.hasSeenPaywall = true
        guard let t = DayKey.ordinal(today) else { return p }
        let offsets = [-62, -48, -35, -40, -22, -18, -9, 4, -12, 6, 10, -5]
        for d in 0..<12 {
            let plan = Program.day(.starter, d + 1)
            let day = DayKey.key(ordinal: t - 12 + d)
            let miss = d < 4 ? 2 : (d < 8 ? 1 : 0)
            let good = max(0, plan.reps / 4 - d / 4)
            let r = SessionRecord(day: day, index: 0, songID: plan.songID, reps: plan.reps, perfect: plan.reps - good - miss, good: good,
                                  miss: miss, maxCombo: plan.reps - miss * 2, score: plan.reps * 110, meanOffsetMs: offsets[d],
                                  course: .starter, planDay: d + 1, endless: false)
            p.record(r, today: day)
        }
        p.bestEndless = 24
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

    var grade: Grade { Grade.from(accuracy: record.accuracy) }
    var tendency: Tendency { Tendency.from(ms: record.meanOffsetMs) }
}
