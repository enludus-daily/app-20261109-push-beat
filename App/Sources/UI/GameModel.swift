import QuartzCore
import SwiftUI
import UIKit

/// 1 曲を遊ぶあいだの状態。時計は CACurrentMediaTime。音（AudioPlayer）も同じ時計に合わせて鳴らす
@MainActor
@Observable
final class GameModel {
    enum Phase: Equatable { case ready, preparing, playing, finished }

    /// 位置につくまでの待ち時間（秒）。はじめるを押してから、床に置いて構えるまで
    static let leadIn = 5.0

    let request: PlayRequest
    let chart: Chart
    let settings: Settings
    private(set) var session: PlaySession
    private(set) var phase: Phase = .ready
    /// 曲の頭（カウントの 1 拍目）の時刻（CACurrentMediaTime）
    private(set) var startTime: Double?
    /// いちばん新しい判定（画面の文字と波紋に使う）
    private(set) var lastEvent: PlaySession.Event?
    private(set) var lastEventTime: Double = 0
    private(set) var touching = false
    /// 撮影用に止めた時刻（曲の頭からの秒）
    private var frozen: Double?

    @ObservationIgnored private let audio: AudioPlayer?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored var onFinish: ((GameModel) -> Void)?

    init(request: PlayRequest, settings: Settings, audio: Bool = true) {
        self.request = request
        self.settings = settings
        self.chart = request.song.chart(reps: request.reps)
        self.session = PlaySession(chart: chart, missLimit: request.endless ? 3 : nil)
        self.audio = audio ? AudioPlayer() : nil
    }

    /// 曲の頭からの秒（調整込み）。始まる前は負
    func songTime(now: Double = CACurrentMediaTime()) -> Double {
        if let frozen { return frozen }
        guard let startTime else { return -Self.leadIn }
        return now - startTime - Double(settings.calibrationMs) / 1000
    }

    func beat(now: Double = CACurrentMediaTime()) -> Double { chart.beat(atSeconds: songTime(now: now)) }

    // MARK: 進行

    func begin() {
        guard phase == .ready else { return }
        phase = .preparing
        let chart = self.chart, mood = request.song.mood
        let music = settings.music, cues = settings.cues
        UIApplication.shared.isIdleTimerDisabled = true
        loop = Task { [weak self] in
            // 音はその場で作る（重いので裏で）
            let samples: [Float]? = (music || cues)
                ? await Task.detached(priority: .userInitiated) { Synth.render(chart: chart, mood: mood, music: music, cues: cues) }.value
                : nil
            guard let self, !Task.isCancelled else { return }
            let start = CACurrentMediaTime() + Self.leadIn
            self.startTime = start
            if let samples { self.audio?.play(samples, at: start) }
            self.phase = .playing
            while !Task.isCancelled, self.phase == .playing {
                self.tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func tick() {
        let t = songTime()
        let events = session.advance(to: t)
        if let e = events.last { show(e) }
        if session.isFinished(at: t) { end() }
    }

    func touchDown() {
        guard !touching else { return }
        touching = true
        guard phase == .playing else { return }
        let t = songTime()
        guard t > -0.5 else { return }
        let before = session.reps
        if let e = session.touchDown(at: t) { show(e) }
        if session.reps > before, session.holding != nil, settings.haptics { Feedback.keepStart() }
    }

    func touchUp() {
        guard touching else { return }
        touching = false
        guard phase == .playing else { return }
        if let e = session.touchUp(at: songTime()) { show(e) }
    }

    private func show(_ e: PlaySession.Event) {
        lastEvent = e
        lastEventTime = CACurrentMediaTime()
        if e.judgement != .miss, settings.cues { audio?.hit(e.judgement) }
        guard settings.haptics else { return }
        switch e.judgement {
        case .perfect: Feedback.perfect(combo: session.combo)
        case .good: Feedback.good()
        case .miss: Feedback.miss()
        }
    }

    func quit() {
        session.endEarly()
        end()
    }

    private func end() {
        guard phase != .finished else { return }
        phase = .finished
        loop?.cancel()
        audio?.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        if settings.haptics { Feedback.finished() }
        onFinish?(self)
    }

    // MARK: 撮影・テスト用

    /// 最初の hits 個を拍どおりに叩いた途中の場面で止める
    func freezeForScreenshot(hits: Int) {
        let n = min(hits, chart.notes.count - 1)
        for i in 0..<n {
            let t = chart.seconds(atBeat: chart.notes[i].beat) + (i % 3 == 2 ? 0.17 : 0.02)
            session.touchDown(at: t)
            session.touchUp(at: chart.seconds(atBeat: chart.notes[i].endBeat) + 0.05)
        }
        // 次のノーツの 0.6 拍前（輪が近づいているところ）
        let next = chart.notes[n].beat - 0.6
        frozen = chart.seconds(atBeat: next)
        lastEvent = session.events.last
        lastEventTime = CACurrentMediaTime()
        phase = .playing
    }

    /// 1 曲を最後まで（ところどころずらして）叩いた結果を作る
    func simulateWholeSong() {
        for (i, note) in chart.notes.enumerated() {
            if i == 9 { continue }  // 1 つ外す
            let wobble = [0.02, -0.05, 0.19, -0.03, 0.06][i % 5]
            session.touchDown(at: chart.seconds(atBeat: note.beat) + wobble)
            session.touchUp(at: chart.seconds(atBeat: note.endBeat) + 0.05)
        }
        session.advance(to: chart.duration + 1)
        phase = .finished
    }
}

// 手応えの振動（README の「手応えの表」と対応）
@MainActor
enum Feedback {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() { light.prepare(); rigid.prepare(); soft.prepare() }
    static func select() { selection.selectionChanged() }
    static func perfect(combo: Int) {
        // 10 コンボごとに強く
        if combo > 0, combo % 10 == 0 { notice.notificationOccurred(.success) } else { rigid.impactOccurred(intensity: 0.75) }
    }
    static func good() { light.impactOccurred(intensity: 0.6) }
    static func miss() { soft.impactOccurred(intensity: 0.3) }
    static func keepStart() { soft.impactOccurred(intensity: 0.6) }
    static func finished() { notice.notificationOccurred(.success) }
}
