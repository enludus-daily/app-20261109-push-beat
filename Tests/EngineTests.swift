import Foundation
import Testing
@testable import PushBeat

struct ChartTests {
    @Test func parsesTapsKeepsAndRests() {
        let notes = Chart.parse("x.k=..x.", offset: 4)
        #expect(notes == [
            Note(beat: 4, kind: .tap),
            Note(beat: 6, kind: .keep(beats: 2)),
            Note(beat: 10, kind: .tap),
        ])
    }

    @Test func makesExactlyTheRequestedReps() {
        for song in Songbook.all {
            for reps in [6, 10, 30, 60] {
                #expect(song.chart(reps: reps).notes.count == reps, "\(song.id) \(reps)")
            }
        }
    }

    @Test func notesStartAfterTheCountInAndAreOrdered() {
        for song in Songbook.all {
            let chart = song.chart(reps: 30)
            #expect(chart.notes.first?.beat == Double(Chart.countIn))
            for (a, b) in zip(chart.notes, chart.notes.dropFirst()) {
                #expect(a.beat < b.beat, "\(song.id)")
            }
        }
    }

    /// 腕立ては速くできないので、ノーツの間（キープなら終わりから次まで）は 0.56 秒以上あける
    @Test func everySongLeavesTimeForAPushUp() {
        for song in Songbook.all {
            let chart = song.chart(reps: 40)
            for (a, b) in zip(chart.notes, chart.notes.dropFirst()) {
                let gap = chart.seconds(atBeat: b.beat) - chart.seconds(atBeat: a.endBeat)
                #expect(gap >= JudgeWindow.good * 2, "\(song.id) beat \(a.beat)")
            }
        }
    }

    @Test func aChartWithNoNotesStops() {
        let chart = Chart.make(bpm: 80, bars: ["....", "...."], reps: 10)
        #expect(chart.notes.isEmpty)
    }

    @Test func durationIncludesTheTail() {
        let chart = Chart.make(bpm: 60, bars: ["x..."], reps: 2)
        // ノーツは 4 拍目と 8 拍目、余韻 4 拍 → 12 拍 = 12 秒
        #expect(chart.totalBeats == 12)
        #expect(chart.duration == 12)
    }

    @Test func songbookHasSixFreeAndTwelveProSongsWithUniqueIDs() {
        #expect(Songbook.free.count == 6)
        #expect(Songbook.pro.count == 12)
        #expect(Set(Songbook.all.map(\.id)).count == Songbook.all.count)
    }
}

struct PlaySessionTests {
    /// 60 BPM：1 拍 1 秒。ノーツは 4・8・12 秒
    let chart = Chart.make(bpm: 60, bars: ["x..."], reps: 3)

    @Test func judgesByDistanceFromTheBeat() {
        #expect(JudgeWindow.judge(offset: 0.05) == .perfect)
        #expect(JudgeWindow.judge(offset: -0.13) == .perfect)
        #expect(JudgeWindow.judge(offset: 0.2) == .good)
        #expect(JudgeWindow.judge(offset: -0.28) == .good)
        #expect(JudgeWindow.judge(offset: 0.4) == nil)
    }

    @Test func hittingOnTheBeatBuildsACombo() {
        var s = PlaySession(chart: chart)
        let r1 = s.touchDown(at: 4.02)
        #expect(r1?.judgement == .perfect)
        s.touchUp(at: 4.3)
        let r2 = s.touchDown(at: 8.2)
        #expect(r2?.judgement == .good)
        s.touchUp(at: 8.5)
        #expect(s.combo == 2)
        #expect(s.maxCombo == 2)
        #expect(s.count.perfect == 1 && s.count.good == 1)
    }

    @Test func aPassedNoteBecomesAMissAndBreaksTheCombo() {
        var s = PlaySession(chart: chart)
        s.touchDown(at: 4.0)
        s.touchUp(at: 4.2)
        let missed = s.advance(to: 8.5)
        #expect(missed.map(\.judgement) == [.miss])
        #expect(s.combo == 0)
        #expect(s.maxCombo == 1)
    }

    @Test func offBeatPushUpsStillCountAsReps() {
        var s = PlaySession(chart: chart)
        s.touchDown(at: 2.0)  // 拍の外（最初のノーツより 2 秒前）
        s.touchUp(at: 2.3)
        #expect(s.reps == 1)
        #expect(s.judgedCount == 0)
    }

    @Test func aBounceOfTheFaceIsOneRep() {
        var s = PlaySession(chart: chart)
        s.touchDown(at: 4.0)
        s.touchUp(at: 4.05)
        s.touchDown(at: 4.15)  // 鼻のあとに頬が触れた
        #expect(s.reps == 1)
    }

    @Test func keepNeedsToStayDownUntilTheEnd() {
        let keepChart = Chart.make(bpm: 60, bars: ["k=.."], reps: 2)  // 4〜6 秒、8〜10 秒
        var s = PlaySession(chart: keepChart)
        let r3 = s.touchDown(at: 4.0)
        #expect(r3 == nil)  // 下ろしただけでは決まらない
        #expect(s.holding != nil)
        let r4 = s.touchUp(at: 6.0)
        #expect(r4?.judgement == .perfect)
        s.touchDown(at: 8.0)
        let r5 = s.touchUp(at: 8.6)
        #expect(r5?.judgement == .good)  // 早く上げた → 1 段下がる
    }

    @Test func keepIsSettledWhenTimePassesItsEnd() {
        let keepChart = Chart.make(bpm: 60, bars: ["k=.."], reps: 1)
        var s = PlaySession(chart: keepChart)
        s.touchDown(at: 4.1)
        let events = s.advance(to: 6.1)
        #expect(events.map(\.judgement) == [.perfect])
        #expect(s.holding == nil)
    }

    @Test func meanOffsetShowsTheTendency() {
        var s = PlaySession(chart: chart)
        s.touchDown(at: 3.9); s.touchUp(at: 4.2)
        s.touchDown(at: 7.9); s.touchUp(at: 8.2)
        #expect(s.meanOffsetMs == -100)
        #expect(Tendency.from(ms: s.meanOffsetMs) == .early)
        #expect(Tendency.from(ms: 10) == .onTime)
        #expect(Tendency.from(ms: 60) == .late)
    }

    @Test func endlessEndsAfterThreeMissesInARow() {
        let long = Chart.make(bpm: 60, bars: ["x..."], reps: 50)
        var s = PlaySession(chart: long, missLimit: 3)
        s.advance(to: 11.0)  // 4・8 秒を外す
        #expect(!s.isFinished(at: 11.0))
        s.advance(to: 12.5)
        #expect(s.isFinished(at: 12.5))
    }

    @Test func finishesAtTheEndOfTheSongOrWhenQuit() {
        var s = PlaySession(chart: chart)
        #expect(!s.isFinished(at: 10))
        #expect(s.isFinished(at: chart.duration))
        s.endEarly()
        #expect(s.isFinished(at: 0))
    }

    @Test func gradeFollowsAccuracy() {
        #expect(Grade.from(accuracy: 1) == .s)
        #expect(Grade.from(accuracy: 0.9) == .a)
        #expect(Grade.from(accuracy: 0.75) == .b)
        #expect(Grade.from(accuracy: 0.2) == .c)
    }
}

struct SynthTests {
    @Test func rendersTheWholeSongWithoutClipping() {
        let chart = Songbook.all[0].chart(reps: 4)
        let samples = Synth.render(chart: chart, mood: .latte, sampleRate: 4_000)
        #expect(samples.count >= Int(chart.duration * 4_000))
        #expect(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
        #expect(samples.contains { abs($0) > 0.01 })
    }

    @Test func everyMoodHasFourChords() {
        for mood in Mood.allCases {
            let st = Synth.style(mood)
            #expect(st.chords.count == 4)
            #expect(st.bass.count == 4)
        }
    }

    @Test func hitSoundsAreShortAndMissIsSilent() {
        #expect(Synth.hitSound(.miss, sampleRate: 4_000).allSatisfy { $0 == 0 })
        #expect(Synth.hitSound(.perfect, sampleRate: 4_000).contains { $0 != 0 })
    }
}
