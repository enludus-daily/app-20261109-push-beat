import Foundation

// 画面の文字の訳。キーは日本語の文（開発の言語は日本語）。訳は App/Resources/Localizable.xcstrings（ja・en）。
// 文の中の数や名前は %@ にして、引数で渡す（英語では %1$@ のように順番を変えてよい）。

enum Localization {
    /// ふだんは端末の言語。撮影のときは、場面の名前が「-en」で終われば英語、それ以外は日本語で出す
    /// （CI の daily-actions の版では起動引数 -AppleLanguages を渡せず、シミュレータは英語なので、アプリの側で言語を決める）
    nonisolated(unsafe) static let bundle: Bundle = {
        guard let scene = UserDefaults.standard.string(forKey: "screenshotScene") else { return .main }
        let language = scene.hasSuffix("-en") ? "en" : "ja"
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"), let b = Bundle(path: path) { return b }
        return .main
    }()
}

/// 日本語の文を、端末の言語に合わせて返す（訳がなければ日本語のまま）
func L(_ key: String) -> String {
    Localization.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// %@ の入った文を訳して、引数を入れる
func L(_ key: String, _ args: String...) -> String {
    String(format: L(key), arguments: args.map { $0 as NSString })
}
