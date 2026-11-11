import Foundation

// 画面の文字の訳。キーは日本語の文（開発の言語は日本語）。訳は App/Resources/en.lproj/Localizable.strings。
// 文の中の数や名前は %@ にして、引数で渡す（英語では %1$@ のように順番を変えてよい）。

/// 日本語の文を、端末の言語に合わせて返す（訳がなければ日本語のまま）
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

/// %@ の入った文を訳して、引数を入れる
func L(_ key: String, _ args: String...) -> String {
    String(format: L(key), arguments: args.map { $0 as NSString })
}
