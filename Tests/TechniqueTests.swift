import Foundation
import Testing
@testable import PushBeat

struct TechniqueTests {
    @Test func eightTechniquesThreeFree() {
        #expect(Technique.allCases.count == 8)
        #expect(Set(Technique.free) == [.standard, .knee, .wide])
    }

    @Test func everyMuscleHasATechniqueAndEveryTechniqueHasAMainMuscle() {
        for m in Muscle.allCases {
            #expect(!Technique.targeting(m).isEmpty, "\(m)")
        }
        for t in Technique.allCases {
            #expect(!t.mainMuscles.isEmpty, "\(t)")
            #expect((2...3).contains(t.form.count), "\(t)")
        }
    }

    /// どのやり方 × どの曲でも、頼んだ回数ちょうど・拍の順・腕立てができる間（0.56 秒以上）
    @Test func everyTechniqueMakesPlayableChartsForEverySong() {
        for t in Technique.allCases {
            for song in Songbook.all {
                let chart = t.chart(song: song, reps: 30)
                #expect(chart.notes.count == 30, "\(t) \(song.id)")
                #expect(chart.notes.first?.beat == Double(Chart.countIn))
                for (a, b) in zip(chart.notes, chart.notes.dropFirst()) {
                    let gap = chart.seconds(atBeat: b.beat) - chart.seconds(atBeat: a.endBeat)
                    #expect(gap >= JudgeWindow.good * 2, "\(t) \(song.id) beat \(a.beat)")
                }
            }
        }
    }

    @Test func rhythmsDifferByTechnique() {
        let song = Songbook.all[2]  // サンセット・ウォーク（2 拍と 4 拍）
        // ゆっくり下ろす：4 拍に 1 回
        let slow = Technique.negative.chart(song: song, reps: 6)
        #expect(zip(slow.notes, slow.notes.dropFirst()).allSatisfy { $1.beat - $0.beat == 4 })
        // 下でキープ：キープが入る
        let hold = Technique.hold.chart(song: song, reps: 6)
        #expect(hold.notes.contains { if case .keep = $0.kind { true } else { false } })
        // ダイヤモンドは少しゆっくり
        #expect(Technique.diamond.bpm(for: song) < song.bpm)
        // ふつうは曲のまま
        #expect(Technique.standard.chart(song: song, reps: 10) == song.chart(reps: 10))
        #expect(Technique.negative.cue == .glide(beats: 3))
        #expect(Technique.standard.cue == .bell)
    }

    @Test func glideCueRendersWithoutClipping() {
        let chart = Technique.negative.chart(song: Songbook.all[0], reps: 3)
        let samples = Synth.render(chart: chart, mood: .latte, sampleRate: 4_000, music: false, cues: true, cue: .glide(beats: 3))
        #expect(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
        // 最初のノーツ（4 拍目）の 3 拍前から、下がる音が鳴っている
        let spb = chart.secondsPerBeat
        let i = Int((spb * 2.5) * 4_000)
        #expect(samples[i..<(i + 200)].contains { abs($0) > 0.005 })
    }
}

struct RepPlanTests {
    @Test func withoutABaselineTheOriginalPathStays() {
        #expect(Program.days(.starter).map(\.reps) == Program.starterReps)
        #expect(Program.days(.advanced).map(\.reps) == Program.advancedReps)
    }

    @Test func aBaselineMakesAPathThatFitsThePerson() {
        let ten = Program.days(.starter, baseline: 10)
        #expect(ten[0].reps == 6)  // 6 割
        #expect(ten[29].reps == 22)  // 1.4 倍 + 8
        let forty = Program.days(.starter, baseline: 40)
        #expect(forty[0].reps == 24)
        #expect(forty[29].reps > ten[29].reps)
        // 軽い日は前の日より少ない
        for d in forty where d.isLight { #expect(d.reps < forty[d.day - 2].reps) }
        // 少しずつ増える（軽い日を除く）
        let normal = forty.filter { !$0.isLight }
        #expect(zip(normal, normal.dropFirst()).allSatisfy { $0.reps <= $1.reps })
        // 強くなる 30 日は、同じ人でも多め
        #expect(Program.day(.advanced, 1, baseline: 10).reps > ten[0].reps)
    }

    @Test func repsNeverGoBelowTheMinimum() {
        #expect(Program.days(.starter, baseline: 1).allSatisfy { $0.reps >= Program.minReps })
        #expect(Program.day(.starter, 1, baseline: 10, shift: -50).reps == Program.minReps)
    }

    @Test func shiftMovesEveryDayAndHalfOnLightDays() {
        let base = Program.day(.starter, 5, baseline: 20).reps
        #expect(Program.day(.starter, 5, baseline: 20, shift: 4).reps == base + 4)
        let light = Program.day(.starter, 7, baseline: 20).reps
        #expect(Program.day(.starter, 7, baseline: 20, shift: 4).reps == light + 2)
    }

    @Test func nudgeChangesTodayAndStopsAtTheMinimum() {
        var p = Progress()
        p.setBaseline(10)
        let today = "2026-11-11"
        let before = p.plan(.starter, today: today).reps
        p.nudge(1, course: .starter, today: today)
        #expect(p.plan(.starter, today: today).reps == before + 1)
        for _ in 0..<20 { p.nudge(-1, course: .starter, today: today) }
        #expect(p.plan(.starter, today: today).reps == Program.minReps)
        // 最小で止まったぶん、shift は下がり続けない
        #expect(p.repShift == Program.minReps - before)
        // 決め直すと調整は 0 に戻る
        p.setBaseline(12)
        #expect(p.repShift == 0)
        #expect(p.baseline == 12)
    }

    @Test func pickedTechniqueLastsOnlyThatDay() {
        var p = Progress()
        let plan = p.plan(.starter, today: "2026-11-11")
        #expect(p.technique(for: plan, today: "2026-11-11") == .knee)
        p.techniquePick = TechniquePick(day: "2026-11-11", technique: .wide)
        #expect(p.technique(for: plan, today: "2026-11-11") == .wide)
        #expect(p.technique(for: plan, today: "2026-11-12") == .knee)
    }
}

struct RepAdviceTests {
    @Test func manyPerfectsAndFinishedSuggestsMore() {
        #expect(RepAdvice.suggest(reps: 20, perfect: 19, good: 1, miss: 0, finished: true) == .up(2))
        #expect(RepAdvice.suggest(reps: 6, perfect: 6, good: 0, miss: 0, finished: true) == .up(1))
    }

    @Test func quittingOrMissingSuggestsLess() {
        #expect(RepAdvice.suggest(reps: 20, perfect: 10, good: 2, miss: 0, finished: false) == .down(2))
        #expect(RepAdvice.suggest(reps: 20, perfect: 8, good: 4, miss: 8, finished: true) == .down(2))
    }

    @Test func inBetweenKeeps() {
        #expect(RepAdvice.suggest(reps: 20, perfect: 14, good: 5, miss: 1, finished: true) == .keep)
        #expect(RepAdvice.suggest(reps: 20, perfect: 0, good: 0, miss: 0, finished: true) == .keep)
        // 最小の回数より下は提案しない
        #expect(RepAdvice.suggest(reps: 3, perfect: 0, good: 1, miss: 2, finished: false) == .keep)
    }

    @Test func deltaSign() {
        #expect(RepAdvice.up(2).delta == 2)
        #expect(RepAdvice.down(3).delta == -3)
        #expect(RepAdvice.keep.delta == 0)
    }
}

struct WeekRecordTests {
    func record(_ day: String, reps: Int, _ t: Technique?, endless: Bool = false, combo: Int = 0, seconds: Int? = nil) -> SessionRecord {
        SessionRecord(day: day, index: 0, songID: "morning-latte", reps: reps, perfect: reps, good: 0, miss: 0, maxCombo: combo, score: 0,
                      meanOffsetMs: 0, course: nil, planDay: nil, endless: endless, technique: t, seconds: seconds)
    }

    @Test func weekRepsAndLoadCountOnlyTheLastSevenDays() {
        var p = Progress()
        p.record(record("2026-11-04", reps: 50, .diamond), today: "2026-11-04")  // 8 日前：入らない
        p.record(record("2026-11-05", reps: 10, .wide), today: "2026-11-05")
        p.record(record("2026-11-11", reps: 20, .wide), today: "2026-11-11")
        p.record(record("2026-11-11", reps: 6, .diamond), today: "2026-11-11")
        let week = p.weekReps(today: "2026-11-11")
        #expect(week.map(\.technique) == [.wide, .diamond])
        #expect(week.map(\.reps) == [30, 6])
        let load = p.weekLoad(today: "2026-11-11")
        #expect(load[.chest] == 33.0, "\(load)")
        #expect(load[.shoulder] == 15.0)
        #expect(load[.triceps] == 6.0)
        #expect(load[.core] == nil)
    }

    @Test func balanceSaysWhenOneMuscleDominates() {
        let chestOnly = MuscleBalance(load: [.chest: 30, .shoulder: 15])
        #expect(chestOnly.top == .chest)
        #expect(chestOnly.isLopsided)
        #expect(chestOnly.headline == "今週は胸ばかり")
        #expect(chestOnly.least == .triceps || chestOnly.least == .core)
        let even = MuscleBalance(load: [.chest: 10, .triceps: 10, .shoulder: 10, .core: 10])
        #expect(!even.isLopsided)
        let empty = MuscleBalance(load: [:])
        #expect(empty.top == nil)
        #expect(!empty.isLopsided)
    }

    @Test func oldRecordsWithoutATechniqueFallBackToThePlanDay() {
        let old = SessionRecord(day: "2026-11-09", index: 0, songID: "morning-latte", reps: 6, perfect: 6, good: 0, miss: 0, maxCombo: 6,
                                score: 0, meanOffsetMs: 0, course: .starter, planDay: 1, endless: false)
        #expect(old.resolvedTechnique == .knee)
        #expect(record("2026-11-09", reps: 6, nil).resolvedTechnique == .standard)
    }

    @Test func endlessKeepsSeparateBests() {
        var p = Progress()
        p.record(record("2026-11-10", reps: 20, .standard, endless: true, combo: 12, seconds: 70), today: "2026-11-10")
        p.record(record("2026-11-11", reps: 15, .standard, endless: true, combo: 15, seconds: 90), today: "2026-11-11")
        #expect(p.endlessBest == EndlessBest(reps: 20, combo: 15, seconds: 90))
    }

    /// 前の版で保存したデータ（新しい項目がない）も読める
    @Test func decodesProgressSavedByThePreviousVersion() throws {
        var p = Progress()
        p.hasOnboarded = true
        p.bestEndless = 24
        p.record(record("2026-11-09", reps: 6, .knee), today: "2026-11-09")
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
        for key in ["bestEndlessCombo", "bestEndlessSeconds", "usedTechniqueTrial", "baseline", "repShift", "techniquePick"] {
            json[key] = nil
        }
        var records = try #require(json["records"] as? [[String: Any]])
        records[0]["technique"] = nil
        records[0]["seconds"] = nil
        json["records"] = records
        let data = try JSONSerialization.data(withJSONObject: json)
        let back = try JSONDecoder().decode(Progress.self, from: data)
        #expect(back.hasOnboarded)
        #expect(back.bestEndless == 24)
        #expect(back.records.count == 1)
        #expect(back.baseline == nil)
        #expect(back.repShift == 0)
        #expect(back.bestEndlessCombo == 0)
    }

    @Test func newFieldsRoundTrip() throws {
        var p = Progress()
        p.setBaseline(18)
        p.repShift = 2
        p.techniquePick = TechniquePick(day: "2026-11-11", technique: .hold)
        p.record(record("2026-11-11", reps: 9, .hold, endless: true, combo: 9, seconds: 40), today: "2026-11-11")
        let back = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(p))
        #expect(back == p)
    }
}
