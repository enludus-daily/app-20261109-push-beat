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
}

/// 端末に保存する進み具合
struct Progress: Codable, Equatable, Sendable {
    var records: [SessionRecord] = []
    /// 次に進むマス（コースごと、1〜31。31 はぜんぶ終わり）
    var nextDay: [Course: Int] = [.starter: 1, .advanced: 1]
    /// そのコースのマスを最後に進めた日
    var lastPlanKey: [Course: String] = [:]
    var bestEndless = 0
    var hasOnboarded = false
    var hasSeenPaywall = false
    /// Pro の曲を 1 回だけ試したか
    var usedProTrial = false
    var settings = Settings()

    var totalReps: Int { records.reduce(0) { $0 + $1.reps } }
    var sessions: Int { records.count }

    func reps(on day: String) -> Int { records.filter { $0.day == day }.reduce(0) { $0 + $1.reps } }

    /// 今日のマス。今日すでに進めていたら、そのマス（もう一度やれる）
    func plan(_ course: Course, today: String) -> PlanDay {
        let next = nextDay[course] ?? 1
        if lastPlanKey[course] == today { return Program.day(course, max(1, next - 1)) }
        return Program.day(course, next)
    }

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
        if r.endless { bestEndless = max(bestEndless, r.reps) }
        guard let course = r.course, let planDay = r.planDay, lastPlanKey[course] != today,
              planDay == (nextDay[course] ?? 1), r.judgedEnough else { return false }
        nextDay[course] = planDay + 1
        lastPlanKey[course] = today
        return true
    }

    func nextIndex(on day: String) -> Int { records.filter { $0.day == day }.count }
}

extension SessionRecord {
    /// 途中でやめた回はマスを進めない（ノーツの半分以上に触れていれば進める）
    var judgedEnough: Bool {
        let n = perfect + good + miss
        return n > 0 && Double(perfect + good) / Double(n) >= 0.5
    }
}
