import Foundation

// 譜面。腕立ての「下ろしてあご・鼻で画面に触れる」1 回が、ノーツ 1 つ。
// 譜面の文字：1 文字が 1 拍。x = 触れる、k = 触れたまま止まる（キープの始まり）、= = キープの続き、. = 休み。

enum NoteKind: Equatable, Sendable {
    case tap
    /// 下で止まる。beats は触れている長さ（拍）
    case keep(beats: Int)
}

struct Note: Equatable, Sendable {
    /// 曲の頭からの拍（カウントの 4 拍を含む）
    let beat: Double
    let kind: NoteKind

    var endBeat: Double {
        switch kind {
        case .tap: beat
        case .keep(let beats): beat + Double(beats)
        }
    }
}

struct Chart: Equatable, Sendable {
    static let countIn = 4
    static let tailBeats = 4

    let bpm: Double
    let notes: [Note]
    /// 曲の長さ（拍）。最後のノーツのあとに 4 拍の余韻
    let totalBeats: Int

    var secondsPerBeat: Double { 60 / bpm }
    func seconds(atBeat beat: Double) -> Double { beat * secondsPerBeat }
    func beat(atSeconds t: Double) -> Double { t / secondsPerBeat }
    var duration: Double { seconds(atBeat: Double(totalBeats)) }

    /// 1 小節の文字列を、ノーツに読む。offset は小節の頭の拍
    static func parse(_ bar: String, offset: Int) -> [Note] {
        var notes: [Note] = []
        let chars = Array(bar)
        var i = 0
        while i < chars.count {
            switch chars[i] {
            case "x":
                notes.append(Note(beat: Double(offset + i), kind: .tap))
                i += 1
            case "k":
                var length = 1
                while i + length < chars.count, chars[i + length] == "=" { length += 1 }
                notes.append(Note(beat: Double(offset + i), kind: .keep(beats: length)))
                i += length
            default:
                i += 1
            }
        }
        return notes
    }

    /// 曲の小節をくり返して、reps 回ぶんのノーツを並べる
    static func make(bpm: Double, bars: [String], reps: Int) -> Chart {
        precondition(!bars.isEmpty)
        var notes: [Note] = []
        var offset = countIn
        var barIndex = 0
        // どの小節にもノーツがない譜面で止まらないように、1 周しても増えなければやめる
        var emptyRun = 0
        while notes.count < reps, emptyRun < bars.count {
            let bar = bars[barIndex % bars.count]
            let parsed = parse(bar, offset: offset)
            emptyRun = parsed.isEmpty ? emptyRun + 1 : 0
            notes.append(contentsOf: parsed.prefix(reps - notes.count))
            offset += bar.count
            barIndex += 1
        }
        let lastEnd = notes.map(\.endBeat).max() ?? Double(countIn)
        return Chart(bpm: bpm, notes: notes, totalBeats: Int(lastEnd.rounded(.up)) + tailBeats)
    }
}
