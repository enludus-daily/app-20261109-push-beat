import Foundation

/// 曲の雰囲気。音（和音・音色・リズム）とジャケットの絵を決める
enum Mood: String, Sendable, CaseIterable, Codable {
    case latte, soda, sunset, rain, citrus, night

    var label: String {
        switch self {
        case .latte: L("lo-fi カフェ")
        case .soda: L("さわやか")
        case .sunset: L("夕焼け")
        case .rain: L("雨の日")
        case .citrus: L("元気")
        case .night: L("夜ふかし")
        }
    }
}

struct Song: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let english: String
    let bpm: Double
    let mood: Mood
    /// 1〜5
    let level: Int
    let isPro: Bool
    /// 譜面の小節（Chart の書き方）。くり返して使う
    let bars: [String]
    /// 曲の紹介（1 行）
    let line: String

    func chart(reps: Int) -> Chart { Chart.make(bpm: bpm, bars: bars, reps: reps) }

    /// キープ（下で止まる）が入っているか
    var hasKeep: Bool { bars.contains { $0.contains("k") } }
}

/// 手で用意した 18 曲（無料 6・Pro 12）
enum Songbook {
    static let all: [Song] = [
        // 無料
        Song(id: "morning-latte", title: L("モーニング・ラテ"), english: "Morning Latte", bpm: 76, mood: .latte, level: 1, isPro: false,
             bars: ["x...", "x...", "x...", "x..."], line: L("4 拍に 1 回。はじめての 1 曲")),
        Song(id: "soda-float", title: L("ソーダフロート"), english: "Soda Float", bpm: 84, mood: .soda, level: 1, isPro: false,
             bars: ["x...", "x...", "x...", "...."], line: L("3 回やって、ひと休み")),
        Song(id: "sunset-walk", title: L("サンセット・ウォーク"), english: "Sunset Walk", bpm: 80, mood: .sunset, level: 2, isPro: false,
             bars: ["x.x.", "x...", "x.x.", "x..."], line: L("2 拍と 4 拍がまざる")),
        Song(id: "rainy-window", title: L("雨の窓辺"), english: "Rainy Window", bpm: 72, mood: .rain, level: 2, isPro: false,
             bars: ["x...", "x...", "k=..", "x..."], line: L("下で 2 拍止まるキープが 1 つ")),
        Song(id: "citrus-step", title: L("シトラス・ステップ"), english: "Citrus Step", bpm: 88, mood: .citrus, level: 3, isPro: false,
             bars: ["x.x.", "x.x.", "x.x.", "...."], line: L("2 拍ずつ 6 回、そして休み")),
        Song(id: "night-drive", title: L("ナイトドライブ"), english: "Night Drive", bpm: 84, mood: .night, level: 3, isPro: false,
             bars: ["x..x..x.", "..x...x.", "x..x..x.", "........"], line: L("3 拍のうねり。夜の高速みたいに")),
        // Pro
        Song(id: "honey-toast", title: L("ハニートースト"), english: "Honey Toast", bpm: 80, mood: .latte, level: 2, isPro: true,
             bars: ["x.x.", "k=..", "x.x.", "x..."], line: L("やさしいキープ入り")),
        Song(id: "lemon-squash", title: L("レモンスカッシュ"), english: "Lemon Squash", bpm: 92, mood: .citrus, level: 3, isPro: true,
             bars: ["x.x.", "x.x.", "x..x", "..x."], line: L("最後に 3 拍の裏切り")),
        Song(id: "blue-hour", title: L("ブルーアワー"), english: "Blue Hour", bpm: 78, mood: .night, level: 3, isPro: true,
             bars: ["x...", "k==.", "..x.", "x..."], line: L("3 拍キープで胸を床へ")),
        Song(id: "cloud-nine", title: L("クラウドナイン"), english: "Cloud Nine", bpm: 96, mood: .soda, level: 4, isPro: true,
             bars: ["x.x.", "x.x.", "x.x.", "x..."], line: L("ずっと 2 拍。息を止めない")),
        Song(id: "petrichor", title: L("ペトリコール"), english: "Petrichor", bpm: 74, mood: .rain, level: 4, isPro: true,
             bars: ["k=..", "x.x.", "k==.", "..x."], line: L("キープが 2 つ。ゆっくり重い")),
        Song(id: "golden-hour", title: L("ゴールデンアワー"), english: "Golden Hour", bpm: 88, mood: .sunset, level: 4, isPro: true,
             bars: ["x..x..x.", "x.x.", "x..x..x.", "...."], line: L("3 拍と 2 拍の切りかえ")),
        Song(id: "midnight-cafe", title: L("ミッドナイトカフェ"), english: "Midnight Cafe", bpm: 84, mood: .latte, level: 3, isPro: true,
             bars: ["x...", "x.x.", "k=..", "x.x."], line: L("夜のカフェで、静かに 30 回")),
        Song(id: "sea-glass", title: L("シーグラス"), english: "Sea Glass", bpm: 100, mood: .soda, level: 5, isPro: true,
             bars: ["x.x.", "x.x.", "x..x", "..x."], line: L("いちばん速い。上級")),
        Song(id: "neon-rain", title: L("ネオンレイン"), english: "Neon Rain", bpm: 94, mood: .rain, level: 5, isPro: true,
             bars: ["x.x.", "k=..", "x..x", "..x.", "k==.", "...."], line: L("速さとキープの両方")),
        Song(id: "orange-peel", title: L("オレンジピール"), english: "Orange Peel", bpm: 98, mood: .citrus, level: 5, isPro: true,
             bars: ["x.x.", "x.x.", "x.x.", "x.x."], line: L("休みなし 8 連")),
        Song(id: "starlight", title: L("スターライト"), english: "Starlight", bpm: 70, mood: .night, level: 4, isPro: true,
             bars: ["k===", "....", "x.x.", "x..."], line: L("4 拍キープ。体幹の曲")),
        Song(id: "after-party", title: L("アフターパーティー"), english: "After Party", bpm: 100, mood: .sunset, level: 5, isPro: true,
             bars: ["x..x..x.", "x.x.", "k=..", "x.x."], line: L("ぜんぶ入り。最後の 1 曲")),
    ]

    static var free: [Song] { all.filter { !$0.isPro } }
    static var pro: [Song] { all.filter(\.isPro) }

    static func song(_ id: String) -> Song? { all.first { $0.id == id } }
}
