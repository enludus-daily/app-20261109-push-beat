# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.001（枠 001 を使い回し。App Store Connect の App はそのまま） |
| アプリ名 | うでたてビート - 腕立てで音ゲー（サブタイトル：拍に合わせて、鼻でタッチ） |
| サポート URL | https://github.com/enludus-daily/app-20261109-push-beat/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261109-push-beat/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」（暴力・性的表現・ギャンブル・Web 閲覧・ユーザー生成コンテンツ・生成 AI なし）→ 4+ の見込み。API では入れないので本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：単純なタイマー・カウンターではなく、18 曲の譜面・拍の判定・30 日の道・くせの記録を持つゲーム。前に作った毎日のアプリ（帳面・記録の型）とも見た目・仕組みが違う
- 既存のアプリとの意味のある違い：腕立てのアプリは「数える」だけ（鼻で触れて数える PushUp Synth も拍の判定はない）。うでたてビートは 1 回ずつを拍で判定し、コンボ・キープの譜面で遊びにする
- 長く使える価値（4.2）：2 つの 30 日の道（6 → 60 回）、18 曲、タイミングのくせの記録で、続けるほど上達が見える
- 他社の名前・商標・見た目を使っていないか：使っていない。曲・音・ジャケットはすべてアプリの中で作った。「音ゲー」は一般名詞
- 健康に関する表示：医療・減量の効果はうたわない。説明文に「無理のない回数で。痛みがあるときは中止」を書いた（1.4.1 の配慮）
- Apple Intelligence：使わない

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro（`com.enludus.daily.001.pro`・¥480・家族共有）。商品は `docs/products.json`、asc.yml の products で作る。審査用の画像は `docs/iap/paywall.png`
- 理由と勝算の表：README の「課金」
- App 内課金の商品は、初めてはアプリのバージョンと一緒に審査に出す（提出は本人）

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない（StoreKit を除く）、解析・広告 SDK なし、保存は端末の UserDefaults だけ。カメラ・マイク・位置情報・HealthKit を使わない。触れたタイミングの記録も端末の中だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
