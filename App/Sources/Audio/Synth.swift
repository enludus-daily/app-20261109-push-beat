import Foundation

/// 曲をその場で作る（音源のファイルを持たない）。譜面の合図の音も、同じ音の中に拍どおりに入れる。
/// 画面・AVAudio から切り離した、ただの計算（テストできる）。
enum Synth {
    struct Style: Sendable {
        /// 和音（MIDI のノート番号）。1 小節（4 拍）に 1 つ
        let chords: [[Int]]
        let bass: [Int]
        /// パッドの明るさ（倍音の量 0〜1）
        let brightness: Float
        /// 裏拍のハイハットの大きさ
        let hat: Float
        /// キックを置く拍（1 小節 4 拍のうち）
        let kicks: [Int]
    }

    static func style(_ mood: Mood) -> Style {
        switch mood {
        case .latte:  // Fmaj7 Em7 Dm7 Cmaj7
            Style(chords: [[65, 69, 72, 76], [64, 67, 71, 74], [62, 65, 69, 72], [60, 64, 67, 71]],
                  bass: [41, 40, 38, 36], brightness: 0.25, hat: 0.05, kicks: [0, 2])
        case .soda:  // C G Am F
            Style(chords: [[60, 64, 67, 72], [59, 62, 67, 71], [57, 60, 64, 69], [57, 60, 65, 69]],
                  bass: [36, 43, 45, 41], brightness: 0.45, hat: 0.08, kicks: [0, 2])
        case .sunset:  // Am F C G
            Style(chords: [[57, 60, 64, 69], [57, 60, 65, 69], [55, 60, 64, 67], [55, 59, 62, 67]],
                  bass: [45, 41, 36, 43], brightness: 0.35, hat: 0.06, kicks: [0, 1, 2, 3])
        case .rain:  // Dm7 G7 Cmaj7 Am7
            Style(chords: [[62, 65, 69, 72], [59, 62, 65, 67], [60, 64, 67, 71], [57, 60, 64, 67]],
                  bass: [38, 43, 36, 45], brightness: 0.2, hat: 0.03, kicks: [0])
        case .citrus:  // D A Bm G
            Style(chords: [[62, 66, 69, 74], [61, 64, 69, 73], [59, 62, 66, 71], [59, 62, 67, 71]],
                  bass: [38, 45, 47, 43], brightness: 0.55, hat: 0.1, kicks: [0, 1, 2, 3])
        case .night:  // Ebmaj7 Cm7 Abmaj7 Bb
            Style(chords: [[63, 67, 70, 74], [60, 63, 67, 70], [56, 60, 63, 67], [58, 62, 65, 70]],
                  bass: [39, 36, 44, 46], brightness: 0.3, hat: 0.07, kicks: [0, 2])
        }
    }

    static func frequency(_ midi: Int) -> Float { 440 * powf(2, Float(midi - 69) / 12) }

    /// モノラルの音を作る。music が false なら合図の音だけ、cues が false なら曲だけ
    static func render(chart: Chart, mood: Mood, sampleRate: Double = 44_100, music: Bool = true, cues: Bool = true) -> [Float] {
        let sr = Float(sampleRate)
        let spb = Float(chart.secondsPerBeat)
        let frames = Int(Float(chart.duration) * sr) + Int(sr)  // 余韻に 1 秒
        var out = [Float](repeating: 0, count: frames)
        let st = style(mood)
        let beats = chart.totalBeats

        out.withUnsafeMutableBufferPointer { buf in
            func add(at start: Float, length: Float, _ sample: (Float) -> Float) {
                let s = Int(start * sr)
                let n = Int(length * sr)
                guard s < buf.count else { return }
                for k in 0..<min(n, buf.count - s) where s + k >= 0 {
                    buf[s + k] += sample(Float(k) / sr)
                }
            }

            // カウント：木の音を 4 つ（4 つめだけ高く）
            for b in 0..<Chart.countIn {
                let f: Float = b == Chart.countIn - 1 ? 1568 : 1046
                add(at: Float(b) * spb, length: 0.12) { t in sinf(2 * .pi * f * t) * expf(-t * 40) * 0.35 }
            }

            if music {
                // 曲はカウントのあとから、最後の拍まで
                var bar = 0
                var beat = Chart.countIn
                while beat < beats {
                    let chord = st.chords[bar % st.chords.count]
                    let root = st.bass[bar % st.bass.count]
                    let barStart = Float(beat) * spb
                    let barLen = spb * 4
                    // パッド：ゆっくり立ち上がる和音
                    for note in chord {
                        let f = frequency(note)
                        add(at: barStart, length: barLen + 0.3) { t in
                            let env = min(1, t / 0.35) * max(0, 1 - max(0, t - barLen) / 0.3)
                            let tone = sinf(2 * .pi * f * t) + st.brightness * 0.4 * sinf(2 * .pi * f * 2 * t) + 0.3 * sinf(2 * .pi * (f * 1.003) * t)
                            return tone * env * 0.035
                        }
                    }
                    // ベース：1 拍目と 3 拍目
                    for b in [0, 2] {
                        let f = frequency(root)
                        add(at: barStart + Float(b) * spb, length: spb * 1.6) { t in
                            let env = min(1, t / 0.01) * expf(-t * 2.2)
                            return (sinf(2 * .pi * f * t) + 0.25 * sinf(2 * .pi * f * 2 * t)) * env * 0.16
                        }
                    }
                    // キック・ハット
                    for b in 0..<4 {
                        let at = barStart + Float(b) * spb
                        if st.kicks.contains(b) {
                            add(at: at, length: 0.3) { t in
                                let f = 50 + 70 * expf(-t * 30)
                                return sinf(2 * .pi * f * t) * expf(-t * 12) * 0.32
                            }
                        }
                        if st.hat > 0 {
                            var seed: UInt32 = UInt32(truncatingIfNeeded: beat * 4 + b) &* 2_654_435_761
                            add(at: at + spb / 2, length: 0.06) { t in
                                seed = seed &* 1_664_525 &+ 1_013_904_223
                                let noise = Float(seed >> 8) / Float(1 << 24) * 2 - 1
                                return noise * expf(-t * 70) * st.hat
                            }
                        }
                    }
                    bar += 1
                    beat += 4
                }
                // 終わりの和音
                let endAt = Float(beats) * spb
                for note in st.chords[0] {
                    let f = frequency(note)
                    add(at: endAt, length: 1) { t in sinf(2 * .pi * f * t) * expf(-t * 3) * 0.05 }
                }
            }

            if cues {
                for note in chart.notes {
                    let at = Float(note.beat) * spb
                    // 1 拍前の小さな音（下ろし始めの合図）
                    add(at: at - spb, length: 0.08) { t in sinf(2 * .pi * 1318 * t) * expf(-t * 60) * 0.08 }
                    // ノーツの音：やわらかいベル
                    add(at: at, length: 0.5) { t in
                        (sinf(2 * .pi * 880 * t) + 0.5 * sinf(2 * .pi * 1760 * t)) * expf(-t * 9) * 0.16
                    }
                    if case .keep(let n) = note.kind {
                        // キープの間：静かにのびる音と、終わりの合図
                        let len = Float(n) * spb
                        add(at: at, length: len) { t in sinf(2 * .pi * 660 * t) * min(1, t / 0.1) * 0.05 }
                        add(at: at + len, length: 0.3) { t in sinf(2 * .pi * 1320 * t) * expf(-t * 14) * 0.12 }
                    }
                }
            }

            // やわらかく頭を抑える
            for i in 0..<buf.count { buf[i] = tanhf(buf[i] * 1.2) * 0.85 }
        }
        return out
    }

    /// 触れたときの短い音
    static func hitSound(_ j: Judgement, sampleRate: Double = 44_100) -> [Float] {
        let sr = Float(sampleRate)
        let n = Int(0.35 * sr)
        return (0..<n).map { i in
            let t = Float(i) / sr
            switch j {
            case .perfect:
                return (sinf(2 * .pi * 1046 * t) + 0.7 * sinf(2 * .pi * 1568 * t) + 0.4 * sinf(2 * .pi * 2093 * t)) * expf(-t * 10) * 0.14
            case .good:
                return sinf(2 * .pi * 784 * t) * expf(-t * 14) * 0.14
            case .miss:
                return 0
            }
        }
    }
}
