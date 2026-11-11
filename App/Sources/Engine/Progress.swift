import Foundation

/// 日付の鍵（端末の暦で YYYY-MM-DD）と、日の数え方
enum DayKey {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// 1970-01-01 からの日数（暦の日で数える。時差や夏時間に左右されない）
    static func ordinal(_ key: String) -> Int? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let date = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    static func key(ordinal: Int) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return key(Date(timeIntervalSince1970: Double(ordinal) * 86_400), calendar: utc)
    }
}

struct SessionRecord: Codable, Equatable, Sendable, Identifiable {
    var id: String { day + "-" + String(index) }
    let day: String
    /// その日の何回目か
    let index: Int
    let songID: String
    let reps: Int
    let perfect: Int
    let good: Int
    let miss: Int
    let maxCombo: Int
    let score: Int
    let meanOffsetMs: Int
    let course: Course?
    let planDay: Int?
    let endless: Bool
    /// やり方（この版から。古い記録は nil → 道の日から決める）
    var technique: Technique? = nil
    /// 続いた秒数（カウントのあとから終わりまで。この版から）
    var seconds: Int? = nil

    /// やり方（古い記録は、道の日のやり方か「ふつう」とみなす）
    var resolvedTechnique: Technique {
        if let technique { return technique }
        if let course, let planDay { return Program.day(course, planDay).technique }
        return .standard
    }

    var accuracy: Double {
        let n = perfect + good + miss
        return n == 0 ? 0 : (Double(perfect) + Double(good) * 0.5) / Double(n)
    }
}

struct DayReps: Equatable, Sendable {
    let day: String
    let reps: Int
}

struct Settings: Codable, Equatable, Sendable {
    var music = true
    var cues = true
    var haptics = true
    /// タイミングの調整（ミリ秒）。プラスなら判定を遅らせる（触れるのが遅れがちな人向け）
    var calibrationMs = 0
    var course: Course = .starter
    /// 毎日のお知らせ（オフが既定）
    var reminder = false
    var reminderHour = 21
}

/// ホームで「今日はこのやり方」と選んだもの（その日だけ効く）
struct TechniquePick: Codable, Equatable, Sendable {
    let day: String
    let technique: Technique
}

/// エンドレスの自己ベスト（それぞれ別に残す）
struct EndlessBest: Codable, Equatable, Sendable {
    var reps = 0
    var combo = 0
    var seconds = 0
}

/// 端末に保存する進み具合
struct Progress: Codable, Equatable, Sendable {
    var records: [SessionRecord] = []
    /// 次に進むマス（コースごと、1〜31。31 はぜんぶ終わり）
    var nextDay: [Course: Int] = [.starter: 1, .advanced: 1]
    /// そのコースのマスを最後に進めた日
    var lastPlanKey: [Course: String] = [:]
    /// エンドレスの最高回数（前の版から）
    var bestEndless = 0
    /// エンドレスの最大コンボと続いた秒数（この版から）
    var bestEndlessCombo = 0
    var bestEndlessSeconds = 0
    var hasOnboarded = false
    var hasSeenPaywall = false
    /// Pro の曲を 1 回だけ試したか
    var usedProTrial = false
    /// Pro のやり方を 1 回だけ試したか
    var usedTechniqueTrial = false
    var settings = Settings()
    /// いまの自分の回数（休まず何回できるか）。決めると 30 日の道がその人に合う
    var baseline: Int?
    /// −／＋ と提案で動かした回数（これからの日にずっと効く）
    var repShift = 0
    var techniquePick: TechniquePick?

    init() {}

    enum CodingKeys: String, CodingKey {
        case records, nextDay, lastPlanKey, bestEndless, bestEndlessCombo, bestEndlessSeconds, hasOnboarded, hasSeenPaywall
        case usedProTrial, usedTechniqueTrial, settings, baseline, repShift, techniquePick
    }

    /// 前の版で保存したもの（新しい項目がない）も読めるように、ない項目は既定の値にする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        records = try c.decodeIfPresent([SessionRecord].self, forKey: .records) ?? []
        nextDay = try c.decodeIfPresent([Course: Int].self, forKey: .nextDay) ?? [.starter: 1, .advanced: 1]
        lastPlanKey = try c.decodeIfPresent([Course: String].self, forKey: .lastPlanKey) ?? [:]
        bestEndless = try c.decodeIfPresent(Int.self, forKey: .bestEndless) ?? 0
        bestEndlessCombo = try c.decodeIfPresent(Int.self, forKey: .bestEndlessCombo) ?? 0
        bestEndlessSeconds = try c.decodeIfPresent(Int.self, forKey: .bestEndlessSeconds) ?? 0
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        hasSeenPaywall = try c.decodeIfPresent(Bool.self, forKey: .hasSeenPaywall) ?? false
        usedProTrial = try c.decodeIfPresent(Bool.self, forKey: .usedProTrial) ?? false
        usedTechniqueTrial = try c.decodeIfPresent(Bool.self, forKey: .usedTechniqueTrial) ?? false
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        baseline = try c.decodeIfPresent(Int.self, forKey: .baseline)
        repShift = try c.decodeIfPresent(Int.self, forKey: .repShift) ?? 0
        techniquePick = try c.decodeIfPresent(TechniquePick.self, forKey: .techniquePick)
    }

    var endlessBest: EndlessBest { EndlessBest(reps: bestEndless, combo: bestEndlessCombo, seconds: bestEndlessSeconds) }

    /// 道のその日（その人の回数で）
    func planDay(_ course: Course, _ n: Int) -> PlanDay { Program.day(course, n, baseline: baseline, shift: repShift) }
    func planDays(_ course: Course) -> [PlanDay] { Program.days(course, baseline: baseline, shift: repShift) }

    /// 今日のやり方：選んでいればそれ、なければ道の日のやり方
    func technique(for plan: PlanDay, today: String) -> Technique {
        if let pick = techniquePick, pick.day == today { return pick.technique }
        return plan.technique
    }

    /// 今日の回数を −／＋ する。回数が最小より下がる分は動かさない
    mutating func nudge(_ delta: Int, course: Course, today: String) {
        let current = plan(course, today: today).reps
        if delta < 0, current <= Program.minReps { return }
        if delta > 0, current >= Program.maxReps { return }
        repShift += delta
    }

    /// いまの自分の回数を決める（−／＋ の調整は 0 に戻す）
    mutating func setBaseline(_ n: Int) {
        baseline = min(max(n, 1), 150)
        repShift = 0
    }

    var totalReps: Int { records.reduce(0) { $0 + $1.reps } }
    var sessions: Int { records.count }

    func reps(on day: String) -> Int { records.filter { $0.day == day }.reduce(0) { $0 + $1.reps } }

    /// 今日のマス。今日すでに進めていたら、そのマス（もう一度やれる）
    func plan(_ course: Course, today: String) -> PlanDay {
        let next = nextDay[course] ?? 1
        if lastPlanKey[course] == today { return planDay(course, max(1, next - 1)) }
        return planDay(course, next)
    }

    /// 次にやるマス（今日の分が終わっていれば明日の分）
    func upcomingPlan(_ course: Course) -> PlanDay { planDay(course, nextDay[course] ?? 1) }

    func planDoneToday(_ course: Course, today: String) -> Bool { lastPlanKey[course] == today }

    func isCourseComplete(_ course: Course) -> Bool { (nextDay[course] ?? 1) > Program.length }

    /// 続けた日数。今日か昨日までつながっている日の数（今日まだでも、昨日までの続きを見せる）
    func streak(today: String) -> Int {
        guard let t = DayKey.ordinal(today) else { return 0 }
        let days = Set(records.compactMap { DayKey.ordinal($0.day) })
        var d = days.contains(t) ? t : t - 1
        var n = 0
        while days.contains(d) { n += 1; d -= 1 }
        return n
    }

    /// 合計の日数（途切れても減らない。「おかえり」の言い方に使う）
    var activeDays: Int { Set(records.map(\.day)).count }

    /// 直近 n 日の回数（古い順）
    func repsByDay(last n: Int, today: String) -> [DayReps] {
        guard let t = DayKey.ordinal(today) else { return [] }
        return (0..<n).reversed().map { back in
            let key = DayKey.key(ordinal: t - back)
            return DayReps(day: key, reps: reps(on: key))
        }
    }

    /// 直近 n 回のくせ（ミリ秒）。エンドレスも含む
    func recentOffsetMs(last n: Int = 10) -> Int? {
        let recent = records.suffix(n)
        guard !recent.isEmpty else { return nil }
        return Int((Double(recent.reduce(0) { $0 + $1.meanOffsetMs }) / Double(recent.count)).rounded())
    }

    /// 1 回遊び終えたときに記録する。今日のマスなら道を進める（1 日 1 マス）。進めたら true
    @discardableResult
    mutating func record(_ r: SessionRecord, today: String) -> Bool {
        records.append(r)
        if r.endless {
            bestEndless = max(bestEndless, r.reps)
            bestEndlessCombo = max(bestEndlessCombo, r.maxCombo)
            bestEndlessSeconds = max(bestEndlessSeconds, r.seconds ?? 0)
        }
        guard let course = r.course, let planDay = r.planDay, lastPlanKey[course] != today,
              planDay == (nextDay[course] ?? 1), r.judgedEnough else { return false }
        nextDay[course] = planDay + 1
        lastPlanKey[course] = today
        return true
    }

    func nextIndex(on day: String) -> Int { records.filter { $0.day == day }.count }

    // MARK: 週の記録（やり方・筋肉）

    /// 直近 7 日（今日を含む）の記録
    func weekRecords(today: String) -> [SessionRecord] {
        guard let t = DayKey.ordinal(today) else { return [] }
        return records.filter { r in
            guard let o = DayKey.ordinal(r.day) else { return false }
            return o > t - 7 && o <= t
        }
    }

    /// この 7 日の、やり方ごとの回数（多い順。0 は入れない）
    func weekReps(today: String) -> [TechniqueReps] {
        var sum: [Technique: Int] = [:]
        for r in weekRecords(today: today) { sum[r.resolvedTechnique, default: 0] += r.reps }
        var out: [TechniqueReps] = []
        for t in Technique.allCases {
            if let n = sum[t], n > 0 { out.append(TechniqueReps(technique: t, reps: n)) }
        }
        return out.sorted { $0.reps > $1.reps }
    }

    /// この 7 日の、筋肉ごとの負荷（回数 × 効き方。主に効く所は 1、補助は 0.5）
    func weekLoad(today: String) -> [Muscle: Double] {
        var load: [Muscle: Double] = [:]
        for r in weekRecords(today: today) {
            for (m, w) in r.resolvedTechnique.load { load[m, default: 0] += Double(r.reps) * w }
        }
        return load
    }
}

struct TechniqueReps: Equatable, Sendable, Identifiable {
    let technique: Technique
    let reps: Int
    var id: Technique { technique }
}

/// 筋肉の偏りを言葉にする（「今週は胸ばかり」）
struct MuscleBalance: Equatable, Sendable {
    /// いちばん多い筋肉と、その割合（0〜1）
    let top: Muscle?
    let topShare: Double
    /// いちばん少ない筋肉（次にすすめる）
    let least: Muscle?

    init(load: [Muscle: Double]) {
        let total = load.values.reduce(0, +)
        guard total > 0 else { top = nil; topShare = 0; least = nil; return }
        let sorted = Muscle.allCases.sorted { (load[$0] ?? 0) > (load[$1] ?? 0) }
        top = sorted.first
        topShare = (load[sorted[0]] ?? 0) / total
        least = sorted.last
    }

    /// 1 つの筋肉が 4 割を超えたら「偏り」（4 つが同じなら 25%。主に効く所 1・補助 0.5 なので、ふつうだけでも胸は 4 割になる）
    var isLopsided: Bool { topShare > 0.4 }

    var headline: String {
        guard let top else { return L("今週はまだ記録がありません") }
        return isLopsided ? L("今週は%@ばかり", "\(top.label)") : L("今週はバランスよく")
    }

    var advice: String {
        guard top != nil, let least else { return L("1 曲やると、どの筋肉をどれだけ使ったかがここに出ます") }
        return isLopsided ? L("次は%@にしてみよう", "\(least.dayTitle)") : L("この調子で。少ないのは%@", "\(least.label)")
    }
}

/// 遊び終えたあとの、次の回数の提案（勝手に変えず、1 タップで受け入れる）
enum RepAdvice: Equatable, Sendable {
    case up(Int), down(Int), keep

    /// 回数の 1 割（最低 1 回）だけ動かす
    static func step(for reps: Int) -> Int { max(1, Int((Double(reps) * 0.1).rounded())) }

    /// Perfect が 85% 以上で、外したのが 5% 以下 → 上げる。最後まで続かなかった・6 割に届かない・4 回に 1 回以上外した → 下げる
    static func suggest(reps: Int, perfect: Int, good: Int, miss: Int, finished: Bool) -> RepAdvice {
        let n = perfect + good + miss
        guard n > 0 else { return .keep }
        let d = step(for: reps)
        if !finished { return reps > Program.minReps ? .down(d) : .keep }
        let perfectRate = Double(perfect) / Double(n)
        let accuracy = (Double(perfect) + Double(good) * 0.5) / Double(n)
        if perfectRate >= 0.85, Double(miss) <= max(1, Double(n) * 0.05) { return reps < Program.maxReps ? .up(d) : .keep }
        if accuracy < 0.6 || Double(miss) > Double(n) * 0.25 { return reps > Program.minReps ? .down(d) : .keep }
        return .keep
    }

    var delta: Int {
        switch self {
        case .up(let d): d
        case .down(let d): -d
        case .keep: 0
        }
    }
}

extension SessionRecord {
    /// 途中でやめた回はマスを進めない（ノーツの半分以上に触れていれば進める）
    var judgedEnough: Bool {
        let n = perfect + good + miss
        return n > 0 && Double(perfect + good) / Double(n) >= 0.5
    }
}
