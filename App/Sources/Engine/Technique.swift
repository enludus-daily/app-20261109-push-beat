import Foundation

// やり方 × 筋肉。腕立てのやり方ごとに「主に効く筋肉」と「譜面の性格（テンポ・キープ・下ろす速さ）」を持つ。
// 効く所は一般的なフォームの説明（主に使われる筋肉）で、効果の約束はしない。

/// 主に使う筋肉（4 つ。体の絵の塗り分けと、週の偏りに使う）
enum Muscle: String, Sendable, Codable, CaseIterable, Identifiable {
    case chest, triceps, shoulder, core

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: "胸"
        case .triceps: "二の腕"
        case .shoulder: "肩の前"
        case .core: "体幹"
        }
    }

    var dayTitle: String { label + "の日" }
}

/// 譜面の性格
enum Rhythm: Equatable, Sendable {
    /// 曲の譜面のまま
    case song
    /// 1 小節に 1 回だけ（重いやり方。1 回ずつ間を取る）
    case sparse
    /// 3 拍かけてゆっくり下ろし、触れたらすっと上げる（ネガティブ）
    case slowLower
    /// 触れたら下で止まる（キープばかり）
    case hold
}

/// 合図の音の性格（Synth が読む）
enum CueStyle: Equatable, Sendable {
    case bell
    /// ノーツの前の beats 拍、下がっていく音で「ゆっくり下ろす」を伝える
    case glide(beats: Int)
}

enum Technique: String, Sendable, Codable, CaseIterable, Identifiable {
    case standard, knee, wide, diamond, negative, hold, decline, pike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "ふつう"
        case .knee: "ひざつき"
        case .wide: "ワイド"
        case .diamond: "ダイヤモンド"
        case .negative: "ゆっくり下ろす"
        case .hold: "下でキープ"
        case .decline: "デクライン"
        case .pike: "パイク"
        }
    }

    var english: String {
        switch self {
        case .standard: "Standard"
        case .knee: "Knee"
        case .wide: "Wide"
        case .diamond: "Diamond"
        case .negative: "Negative"
        case .hold: "Hold"
        case .decline: "Decline"
        case .pike: "Pike"
        }
    }

    /// 無料は基本の 3 つ（README の「課金」に理由）
    var isPro: Bool {
        switch self {
        case .standard, .knee, .wide: false
        default: true
        }
    }

    /// 効く所（1 = 主に、0.5 = 補助）
    var load: [Muscle: Double] {
        switch self {
        case .standard: [.chest: 1, .triceps: 0.5, .shoulder: 0.5, .core: 0.5]
        case .knee: [.chest: 1, .triceps: 0.5]
        case .wide: [.chest: 1, .shoulder: 0.5]
        case .diamond: [.triceps: 1, .chest: 0.5]
        case .negative: [.chest: 1, .triceps: 1]
        case .hold: [.core: 1, .chest: 0.5, .triceps: 0.5]
        case .decline: [.shoulder: 1, .chest: 0.5, .core: 0.5]
        case .pike: [.shoulder: 1, .triceps: 0.5]
        }
    }

    var mainMuscles: [Muscle] { Muscle.allCases.filter { load[$0] == 1 } }
    var subMuscles: [Muscle] { Muscle.allCases.filter { load[$0] == 0.5 } }

    /// 1〜5
    var level: Int {
        switch self {
        case .knee: 1
        case .standard, .wide: 2
        case .hold: 3
        case .diamond, .negative, .decline: 4
        case .pike: 5
        }
    }

    var rhythm: Rhythm {
        switch self {
        case .standard, .knee, .wide: .song
        case .diamond, .decline: .song
        case .negative: .slowLower
        case .hold: .hold
        case .pike: .sparse
        }
    }

    /// 曲のテンポに掛ける数（重いやり方は少し遅く）
    var tempoScale: Double {
        switch self {
        case .diamond: 0.92
        case .decline: 0.9
        default: 1
        }
    }

    var cue: CueStyle {
        rhythm == .slowLower ? .glide(beats: 3) : .bell
    }

    /// 譜面の性格を 1 行で
    var rhythmLine: String {
        switch rhythm {
        case .song: tempoScale < 1 ? "曲の譜面を、少しゆっくり" : "曲の譜面のまま"
        case .sparse: "1 小節に 1 回。1 回ずつ間を取る"
        case .slowLower: "下がる音に合わせて 3 拍で下ろす"
        case .hold: "触れたら下で 2〜3 拍止まる"
        }
    }

    /// フォームの要点（2〜3 行）
    var form: [String] {
        switch self {
        case .standard: ["手は肩の真下、指は前へ", "かかとから頭まで 1 枚の板に", "ひじは体から 45 度くらい"]
        case .knee: ["ひざをついて、ひざから頭までまっすぐ", "おしりが上がらないように", "回数より、胸を床に近づけることを大事に"]
        case .wide: ["手を肩幅の 1.5 倍に開く", "胸から床へ下ろす", "ひじが肩より上に出ないように"]
        case .diamond: ["両手の親指と人さし指で三角形を作る", "ひじを体に沿わせて下ろす", "きつければひざをついてOK"]
        case .negative: ["下がる音に合わせて 3 拍かけて下ろす", "触れたら、ふつうの速さで上げる", "下ろす間も息を止めない"]
        case .hold: ["触れたら、そのまま止まる", "おなかに力を入れて、腰を落とさない", "上げるのは、終わりの音が鳴ってから"]
        case .decline: ["足を低い台（ソファのふちなど）にのせる", "高さはひざくらいまで。滑らない台で", "首を長く、頭から下ろす"]
        case .pike: ["おしりを高く上げて、体を「へ」の字に", "頭を手の間へ下ろす。iPhone は手の少し前に", "首を痛めないよう、ゆっくり"]
        }
    }

    static var free: [Technique] { allCases.filter { !$0.isPro } }

    /// その筋肉に「主に」効くやり方
    static func targeting(_ m: Muscle) -> [Technique] { allCases.filter { $0.load[m] == 1 } }

    // MARK: 譜面

    /// やり方に合わせた譜面の小節
    func bars(for song: Song) -> [String] {
        switch rhythm {
        case .song: song.bars
        case .sparse:
            // 曲の小節の頭の拍に 1 回だけ（4 拍ごと）。曲の雰囲気は残す
            song.bars.map { bar in "x" + String(repeating: ".", count: max(3, bar.count - 1)) }
        case .slowLower:
            ["x...", "x...", "x...", "x..."]
        case .hold:
            ["k=..", "x...", "k==.", "...."]
        }
    }

    func bpm(for song: Song) -> Double { (song.bpm * tempoScale).rounded() }

    func chart(song: Song, reps: Int) -> Chart {
        Chart.make(bpm: bpm(for: song), bars: bars(for: song), reps: reps)
    }
}
