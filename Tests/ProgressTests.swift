import Foundation
import Testing
@testable import PushBeat

struct ProgramTests {
    @Test func bothCoursesHaveThirtyDaysThatGrow() {
        for course in Course.allCases {
            let days = Program.days(course)
            #expect(days.count == 30)
            #expect(days.last!.reps > days.first!.reps)
            #expect(days.allSatisfy { Songbook.song($0.songID) != nil })
            #expect(days.allSatisfy { !$0.tip.isEmpty })
        }
    }

    @Test func starterUsesOnlyFreeSongsAndAdvancedOnlyPro() {
        #expect(Program.days(.starter).allSatisfy { !$0.song.isPro })
        #expect(Program.days(.advanced).allSatisfy { $0.song.isPro })
    }

    @Test func everySeventhDayIsLight() {
        let days = Program.days(.starter)
        for d in days where d.isLight {
            #expect(d.reps < days[d.day - 2].reps)
        }
    }
}

struct ProgressTests {
    func record(_ day: String, reps: Int = 10, planDay: Int? = nil, perfect: Int = 8, miss: Int = 0, endless: Bool = false) -> SessionRecord {
        SessionRecord(day: day, index: 0, songID: "morning-latte", reps: reps, perfect: perfect, good: reps - perfect - miss, miss: miss,
                      maxCombo: reps, score: 0, meanOffsetMs: -20, course: planDay == nil ? nil : .starter, planDay: planDay, endless: endless)
    }

    @Test func clearingTodaysPlanMovesOneStepPerDay() {
        var p = Progress()
        #expect(p.plan(.starter, today: "2026-11-09").day == 1)
        let first = p.record(record("2026-11-09", planDay: 1), today: "2026-11-09")
        #expect(first)
        // 同じ日にもう一度遊んでも、道は進まない
        #expect(p.plan(.starter, today: "2026-11-09").day == 1)
        #expect(p.planDoneToday(.starter, today: "2026-11-09"))
        let again = p.record(record("2026-11-09", planDay: 1), today: "2026-11-09")
        #expect(!again)
        // 次の日は 2 日目
        #expect(p.plan(.starter, today: "2026-11-10").day == 2)
    }

    @Test func aMostlyMissedRunDoesNotClearTheDay() {
        var p = Progress()
        let cleared = p.record(record("2026-11-09", reps: 6, planDay: 1, perfect: 1, miss: 5), today: "2026-11-09")
        #expect(!cleared)
        #expect(p.plan(.starter, today: "2026-11-09").day == 1)
    }

    @Test func streakCountsConsecutiveDaysUpToTodayOrYesterday() {
        var p = Progress()
        for day in ["2026-11-05", "2026-11-07", "2026-11-08"] { p.record(record(day), today: day) }
        #expect(p.streak(today: "2026-11-09") == 2)  // 今日はまだ。昨日までの 2 日
        p.record(record("2026-11-09"), today: "2026-11-09")
        #expect(p.streak(today: "2026-11-09") == 3)
        #expect(p.streak(today: "2026-11-12") == 0)
        #expect(p.activeDays == 4)
    }

    @Test func streakCrossesMonthEnds() {
        var p = Progress()
        for day in ["2026-10-30", "2026-10-31", "2026-11-01"] { p.record(record(day), today: day) }
        #expect(p.streak(today: "2026-11-01") == 3)
    }

    @Test func repsByDayFillsEmptyDaysWithZero() {
        var p = Progress()
        p.record(record("2026-11-08", reps: 12), today: "2026-11-08")
        p.record(record("2026-11-09", reps: 6), today: "2026-11-09")
        p.record(record("2026-11-09", reps: 4), today: "2026-11-09")
        let week = p.repsByDay(last: 3, today: "2026-11-09")
        #expect(week.map(\.day) == ["2026-11-07", "2026-11-08", "2026-11-09"])
        #expect(week.map(\.reps) == [0, 12, 10])
        #expect(p.totalReps == 22)
    }

    @Test func endlessKeepsTheBest() {
        var p = Progress()
        p.record(record("2026-11-09", reps: 18, endless: true), today: "2026-11-09")
        p.record(record("2026-11-09", reps: 12, endless: true), today: "2026-11-09")
        #expect(p.bestEndless == 18)
    }

    @Test func savesAndLoadsAsJSON() throws {
        var p = Progress()
        p.record(record("2026-11-09", planDay: 1), today: "2026-11-09")
        p.settings.calibrationMs = 40
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Progress.self, from: data)
        #expect(back == p)
    }

    @Test func dayKeysRoundTrip() {
        let o = DayKey.ordinal("2026-11-09")
        #expect(o != nil)
        #expect(DayKey.key(ordinal: o!) == "2026-11-09")
        #expect(DayKey.key(ordinal: o! + 23) == "2026-12-02")
    }
}
