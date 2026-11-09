import Foundation

enum Judgement: String, Sendable, Codable, CaseIterable {
    case perfect, good, miss

    var label: String {
        switch self {
        case .perfect: "Perfect"
        case .good: "Good"
        case .miss: "Miss"
        }
    }

    var points: Int {
        switch self {
        case .perfect: 100
        case .good: 50
        case .miss: 0
        }
    }

    /// キープを早く上げたときに 1 段下げる
    var downgraded: Judgement {
        switch self {
        case .perfect: .good
        case .good, .miss: .miss
        }
    }
}

/// 判定の幅（秒）。腕立ては指より遅れやすいので、音ゲーとしては広め
enum JudgeWindow {
    static let perfect = 0.13
    static let good = 0.28
    /// キープの終わりより、これ以上早く上げたら「早く上がった」
    static let keepRelease = 0.25
    /// これより短い間隔の触れ直しは、同じ 1 回（鼻と頬が続けて触れた、など）
    static let sameRep = 0.35

    static func judge(offset: Double) -> Judgement? {
        let a = abs(offset)
        if a <= perfect { return .perfect }
        if a <= good { return .good }
        return nil
    }
}

/// 1 曲ぶんの遊びの状態。時刻は「曲の頭（カウントの 1 拍目）からの秒」。画面と音から切り離してテストする
struct PlaySession: Sendable {
    struct Event: Equatable, Sendable {
        let index: Int
        let judgement: Judgement
        /// 触れた時刻 - ノーツの時刻（秒）。負ならはやい
        let offset: Double?
    }

    let chart: Chart
    /// フリー（エンドレス）のとき、続けてこの数だけ外したら終わる
    let missLimit: Int?

    private(set) var results: [Judgement?]
    private(set) var offsets: [Double] = []
    private(set) var combo = 0
    private(set) var maxCombo = 0
    private(set) var score = 0
    /// 実際に触れた回数（＝やった腕立ての回数。拍に合わなくても数える）
    private(set) var reps = 0
    private(set) var consecutiveMisses = 0
    private(set) var events: [Event] = []
    /// いまキープしているノーツと、下ろしたときの判定
    private(set) var holding: (index: Int, judgement: Judgement, offset: Double)?
    private var lastTouch: Double?
    private var cursor = 0
    private(set) var endedEarly = false

    init(chart: Chart, missLimit: Int? = nil) {
        self.chart = chart
        self.missLimit = missLimit
        self.results = Array(repeating: nil, count: chart.notes.count)
    }

    func time(of index: Int) -> Double { chart.seconds(atBeat: chart.notes[index].beat) }
    func endTime(of index: Int) -> Double { chart.seconds(atBeat: chart.notes[index].endBeat) }

    var count: (perfect: Int, good: Int, miss: Int) {
        var p = 0, g = 0, m = 0
        for r in results {
            switch r {
            case .perfect: p += 1
            case .good: g += 1
            case .miss: m += 1
            case nil: break
            }
        }
        return (p, g, m)
    }

    var judgedCount: Int { results.compactMap { $0 }.count }

    /// 0〜1。Perfect を 1、Good を 0.5 として、判定済みのノーツで割る
    var accuracy: Double {
        let c = count
        let judged = c.perfect + c.good + c.miss
        guard judged > 0 else { return 0 }
        return (Double(c.perfect) + Double(c.good) * 0.5) / Double(judged)
    }

    /// 触れたタイミングのくせ（ミリ秒）。負ならはやめ
    var meanOffsetMs: Int {
        guard !offsets.isEmpty else { return 0 }
        return Int((offsets.reduce(0, +) / Double(offsets.count) * 1000).rounded())
    }

    func isFinished(at t: Double) -> Bool {
        if endedEarly { return true }
        if let limit = missLimit, consecutiveMisses >= limit { return true }
        return t >= chart.duration
    }

    /// 次に叩くノーツ（画面の輪に使う）
    var nextIndex: Int? {
        var i = cursor
        while i < results.count {
            if results[i] == nil, holding?.index != i { return i }
            i += 1
        }
        return nil
    }

    // MARK: 入力

    @discardableResult
    mutating func touchDown(at t: Double) -> Event? {
        if let last = lastTouch, t - last < JudgeWindow.sameRep { return nil }
        lastTouch = t
        reps += 1
        advance(to: t)
        guard let i = nextIndex else { return nil }
        let offset = t - time(of: i)
        guard let j = JudgeWindow.judge(offset: offset) else { return nil }  // 拍の外の 1 回は数えるが、判定はしない
        offsets.append(offset)
        switch chart.notes[i].kind {
        case .tap:
            return finalize(i, j, offset: offset)
        case .keep:
            holding = (i, j, offset)
            return nil
        }
    }

    @discardableResult
    mutating func touchUp(at t: Double) -> Event? {
        guard let h = holding else { return nil }
        holding = nil
        let early = t < endTime(of: h.index) - JudgeWindow.keepRelease
        return finalize(h.index, early ? h.judgement.downgraded : h.judgement, offset: h.offset)
    }

    /// 時刻を進め、窓を過ぎたノーツを Miss に、終わったキープを確定する。新しく決まった判定を返す
    @discardableResult
    mutating func advance(to t: Double) -> [Event] {
        var new: [Event] = []
        if let h = holding, t >= endTime(of: h.index) {
            holding = nil
            new.append(finalize(h.index, h.judgement, offset: h.offset))
        }
        while cursor < results.count {
            if results[cursor] != nil || holding?.index == cursor {
                if results[cursor] != nil { cursor += 1; continue }
                break
            }
            if t > time(of: cursor) + JudgeWindow.good {
                new.append(finalize(cursor, .miss, offset: nil))
                cursor += 1
            } else {
                break
            }
        }
        return new
    }

    mutating func endEarly() { endedEarly = true }

    private mutating func finalize(_ i: Int, _ j: Judgement, offset: Double?) -> Event {
        results[i] = j
        if j == .miss {
            combo = 0
            consecutiveMisses += 1
        } else {
            combo += 1
            maxCombo = max(maxCombo, combo)
            consecutiveMisses = 0
            score += j.points + min(combo, 20) * 2
        }
        let event = Event(index: i, judgement: j, offset: offset)
        events.append(event)
        return event
    }
}

/// 結果の段階
enum Grade: String, Sendable, Codable {
    case s = "S", a = "A", b = "B", c = "C"

    static func from(accuracy: Double) -> Grade {
        switch accuracy {
        case 0.95...: .s
        case 0.85..<0.95: .a
        case 0.7..<0.85: .b
        default: .c
        }
    }

    var line: String {
        switch self {
        case .s: "拍とからだが、ぴったり"
        case .a: "いいリズム。あと少しで S"
        case .b: "ちゃんと続いた。次は輪を見て"
        case .c: "まずは最後までやれたのが一番"
        }
    }
}

/// くせ（はやい・おそい）を言葉にする
enum Tendency: Equatable, Sendable {
    case early, onTime, late

    static func from(ms: Int) -> Tendency {
        if ms <= -40 { return .early }
        if ms >= 40 { return .late }
        return .onTime
    }

    var label: String {
        switch self {
        case .early: "はやめ"
        case .onTime: "ちょうど"
        case .late: "おそめ"
        }
    }

    var advice: String {
        switch self {
        case .early: "下ろすのが少し急ぎ気味。輪が的に重なるまで待ってから"
        case .onTime: "拍どおり。このまま回数を増やそう"
        case .late: "下ろし始めが遅め。ひとつ前の小さな音で下ろし始めて"
        }
    }
}
