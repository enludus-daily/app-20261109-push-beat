import Foundation

/// 30 日の道。1 日に 1 マス進む
enum Course: String, Sendable, Codable, CaseIterable {
    /// 無料。ひざつき 6 回から、ふつうの腕立て 30 回まで
    case starter
    /// Pro。20 回から 60 回、キープとワイド・ダイヤモンド
    case advanced

    var title: String {
        switch self {
        case .starter: "はじめての 30 日"
        case .advanced: "つよくなる 30 日"
        }
    }

    var isPro: Bool { self == .advanced }
}

struct PlanDay: Equatable, Sendable {
    let course: Course
    /// 1〜30
    let day: Int
    let songID: String
    let reps: Int
    /// やり方（ひざつき・ふつう・ワイド など）。ホームで今日だけ変えられる
    let technique: Technique
    let tip: String
    /// 軽めの日（7 日ごと）
    var isLight: Bool { day % 7 == 0 }

    var song: Song { Songbook.song(songID) ?? Songbook.all[0] }
}

enum Program {
    static let length = 30

    /// baseline：いまの自分の回数（休まず何回できるか）。決めていなければ、はじめから用意した回数。
    /// shift：−／＋ と提案で動かした分（軽い日は半分だけ効く）
    static func day(_ course: Course, _ n: Int, baseline: Int? = nil, shift: Int = 0) -> PlanDay {
        let d = min(max(n, 1), length)
        let r = reps(course, d, baseline: baseline, shift: shift)
        switch course {
        case .starter:
            return PlanDay(course: course, day: d, songID: starterSong(d), reps: r,
                           technique: d <= 10 ? .knee : .standard, tip: starterTips[d - 1])
        case .advanced:
            let techniques: [Technique] = [.standard, .wide, .standard, .diamond, .hold]
            return PlanDay(course: course, day: d, songID: advancedSongs[(d - 1) % advancedSongs.count], reps: r,
                           technique: techniques[(d - 1) % techniques.count], tip: advancedTips[(d - 1) % advancedTips.count])
        }
    }

    static func days(_ course: Course, baseline: Int? = nil, shift: Int = 0) -> [PlanDay] {
        (1...length).map { day(course, $0, baseline: baseline, shift: shift) }
    }

    static let minReps = 3
    static let maxReps = 200

    /// その日の回数。baseline があれば、その人に合わせた道（はじめ 6〜8 割 → 30 日目にだいたい 1.4〜1.7 倍＋α）
    static func reps(_ course: Course, _ d: Int, baseline: Int?, shift: Int) -> Int {
        let day = min(max(d, 1), length)
        let light = day % 7 == 0
        let base: Double
        if let given = baseline {
            let b = Double(min(max(given, 1), 150))
            let (start, end): (Double, Double) = course == .starter ? (b * 0.6, b * 1.4 + 8) : (b * 0.8, b * 1.7 + 10)
            let curve = start + (end - start) * Double(day - 1) / Double(length - 1)
            base = light ? curve * 0.6 : curve
        } else {
            base = Double(course == .starter ? starterReps[day - 1] : advancedReps[day - 1])
        }
        let s = light ? Double(shift) / 2 : Double(shift)
        return min(maxReps, max(minReps, Int((base + s).rounded())))
    }

    // 回数：少しずつ増え、7 日ごとに軽い日
    static let starterReps = [6, 6, 8, 8, 10, 10, 6, 10, 12, 12, 14, 14, 16, 8, 16, 18, 18, 20, 20, 22, 10, 22, 24, 24, 26, 28, 28, 12, 30, 30]
    static let advancedReps = [20, 22, 24, 26, 28, 30, 16, 30, 32, 34, 36, 38, 40, 20, 40, 42, 44, 46, 48, 50, 24, 50, 52, 54, 56, 58, 60, 30, 60, 60]

    private static func starterSong(_ d: Int) -> String {
        // 1 週目はやさしい 2 曲、2 週目から 4 曲、3 週目から 6 曲全部
        let pool: [String]
        switch d {
        case 1...7: pool = ["morning-latte", "soda-float"]
        case 8...14: pool = ["morning-latte", "soda-float", "sunset-walk", "rainy-window"]
        default: pool = Songbook.free.map(\.id)
        }
        return pool[(d - 1) % pool.count]
    }

    private static let advancedSongs = ["honey-toast", "lemon-squash", "blue-hour", "midnight-cafe", "golden-hour", "cloud-nine",
                                        "petrichor", "starlight", "sea-glass", "orange-peel", "neon-rain", "after-party"]

    static let starterTips = [
        "ひざをついてOK。画面の上に頭がくるように置こう",
        "鼻でもあごでも、どこで触れてもいい。触れたら 1 回",
        "下ろすのは、輪が的に重なる瞬間。早すぎないように",
        "手は肩の真下。指は前に向けて",
        "息は下ろすときに吸って、上げるときに吐く",
        "おなかに少し力を入れると、腰が落ちない",
        "軽い日。6 回だけ、ていねいに",
        "ひじは体から 45 度くらい。開きすぎない",
        "ひとつ前の小さな音で、下ろし始めると合う",
        "10 日目。ここまで来たら、もう習慣の入口",
        "今日からひざを伸ばす。きつければ途中からひざつきでOK",
        "かかとから頭まで、まっすぐの板になるイメージ",
        "ゆっくり下ろして、すっと上げる",
        "軽い日。8 回だけ。からだを休めるのも練習",
        "拍がずれたら、次の輪で取り戻せばいい",
        "首は下に向けたまま。顔を上げると肩がつらい",
        "Good でも回数はちゃんと数えている",
        "20 回に近づいてきた。途中の休みの小節で息を整えて",
        "胸が先に下りるように。おしりが先に下りないように",
        "ここで 3 分の 2。最初の日の 3 倍以上やっている",
        "軽い日。10 回だけ。記録を見返してみよう",
        "キープの曲は、下でじっと止まる。触れたまま 2 拍",
        "肩がすくまないように、首を長く",
        "手のひら全体で床を押す",
        "26 回。最初の日を思い出して",
        "テンポのくせを記録で見てみよう。はやめ？おそめ？",
        "ラストスパート。休みの小節は全力で休む",
        "軽い日。12 回だけ。明日に向けて",
        "30 回。ここまで来た自分をほめよう",
        "最終日。30 回を、拍どおりに",
    ]

    static let advancedTips = [
        "ワイドは手を肩幅の 1.5 倍に。胸に効く",
        "ダイヤモンドは両手の親指と人さし指で三角形。二の腕に効く",
        "キープは下で止まる。触れたまま、からだをまっすぐ",
        "速い曲は、上げきらずに次へ。でも胸は床まで",
        "軽い日は回数を減らして、Perfect だけを狙う",
        "60 回は 3 つに分けて考える。20 回ずつ",
        "息を止めない。止めると後半で崩れる",
        "疲れてきたらひざをついてOK。曲は止めない",
        "3 拍の曲はうねりに乗る。体で拍を数えない",
        "キープの終わりまで待ってから上げる。早く上げると Good",
        "ダイヤモンドの日は、ひじを体に沿わせる",
        "記録の「くせ」を見て、ずれを直す日にしよう",
        "後半ほど拍がおそめになりやすい。気持ち早めに",
        "ワイドの日は、胸をしっかり床へ",
        "最後の 10 回がいちばん効いている",
    ]
}
