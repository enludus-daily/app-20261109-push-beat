import StoreKit
import SwiftUI

/// Pro（買い切り）。5 つのやり方と筋肉のメニュー・週の筋肉の偏り・12 曲・つよくなる 30 日・詳しい記録。中身を見せてから値段を出す
struct ProView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Caption("Push Beat Pro", color: Theme.peachDeep)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.paper))
                            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                    }
                    .accessibilityLabel("とじる")
                }
                Text(app.isPro ? "ありがとう。ぜんぶ使えます" : "腕立てを、\nもっと長く楽しく。")
                    .font(Theme.serif(30, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
                Text("1 回買えば、ずっと使えます。家族共有にも対応しています。")
                    .font(Theme.text(14)).foregroundStyle(Theme.inkSoft)

                // 中身 1：やり方と筋肉
                benefit("5 つのやり方と、筋肉のメニュー", "ダイヤモンド（二の腕）・ゆっくり下ろす・下でキープ（体幹）・デクライン・パイク（肩の前）。やり方ごとに譜面と合図の音が変わる") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Technique.allCases.filter(\.isPro)) { t in
                                VStack(alignment: .leading, spacing: 4) {
                                    BodyFigure(technique: t, showPhone: false)
                                        .frame(width: 96, height: 54)
                                        .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).fill(Theme.skyMist))
                                    Text(t.title).font(Theme.label(10)).foregroundStyle(Theme.ink).lineLimit(1)
                                    Text("主に" + t.mainMuscles.map(\.label).joined(separator: "・")).font(Theme.label(9)).foregroundStyle(Theme.inkSoft).lineLimit(1)
                                }
                                .frame(width: 96)
                            }
                        }
                    }
                }
                // 中身 2：週の筋肉の偏り
                benefit("今週は胸ばかり、が分かる", "この 7 日に使った筋肉を、体の絵と棒で。少ない筋肉の日をすすめます") {
                    HStack(spacing: 6) {
                        ForEach(Muscle.allCases) { m in
                            let v: CGFloat = m == .chest ? 1 : (m == .triceps ? 0.45 : (m == .core ? 0.3 : 0.2))
                            VStack(spacing: 3) {
                                Capsule().fill(m == .chest ? Theme.peach : Theme.sky).frame(width: 10, height: 40 * v)
                                    .frame(height: 40, alignment: .bottom)
                                Text(m.label).font(Theme.label(9)).foregroundStyle(Theme.inkSoft)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                // 中身 3：曲
                benefit("12 曲がふえる（全 18 曲）", "キープ・3 拍のうねり・BPM 100 の速い曲まで。むずかしさ 5 の曲は Pro だけ") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Songbook.pro) { song in
                                VStack(alignment: .leading, spacing: 4) {
                                    Jacket(song: song).frame(width: 84)
                                    Text(song.title).font(Theme.label(10)).foregroundStyle(Theme.ink).lineLimit(1).frame(width: 84, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                // 中身 4：つよくなる 30 日
                benefit("つよくなる 30 日", "はじめての 30 日のあとに。回数多めで、ワイド・ダイヤモンド・キープの日が入る") {
                    HStack(spacing: 6) {
                        ForEach([1, 5, 10, 15, 20, 25, 30], id: \.self) { d in
                            let plan = app.progress.planDay(.advanced, d)
                            VStack(spacing: 2) {
                                Text("\(plan.reps)").font(Theme.serif(15, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                                Text("Day \(d)").font(Theme.label(9)).foregroundStyle(Theme.inkSoft)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).fill(Theme.skyMist))
                        }
                    }
                }
                // 中身 5：記録
                benefit("30 日の回数と、くせの移り変わり", "はやめ・おそめのくせが、日ごとにどう直ってきたかが分かる。1 曲ずつの段階も残る") {
                    TendencyMeter(ms: -28)
                }

                purchaseArea
                if let m = message { Text(m).font(Theme.text(13)).foregroundStyle(Theme.ink) }
                HStack {
                    Button("購入を復元") {
                        Task {
                            busy = true
                            await app.store.restore()
                            busy = false
                            message = app.isPro ? "復元しました" : "復元できる購入が見つかりませんでした"
                        }
                    }
                    .font(Theme.text(13)).foregroundStyle(Theme.skyDeep)
                    Spacer()
                }
                Text("回数の調整・エンドレス・基本の 3 つのやり方（ふつう・ひざつき・ワイド）・はじめての 30 日・無料の 6 曲・7 日の記録は、Pro がなくてもずっと使えます。広告はありません。Pro の曲と Pro のやり方は、それぞれ 1 回だけ無料で試せます。")
                    .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.ground.ignoresSafeArea())
        .task { if app.store.loadState == .idle { await app.store.load() } }
    }

    @ViewBuilder private var purchaseArea: some View {
        if app.isPro {
            Label("Pro を使っています", systemImage: "checkmark.seal").font(Theme.text(16, .medium)).foregroundStyle(Theme.skyDeep)
        } else if let product = app.store.products.first {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Task {
                        busy = true
                        let outcome = await app.store.purchase(product)
                        busy = false
                        switch outcome {
                        case .purchased: Feedback.finished(); message = "ようこそ Pro へ"
                        case .pending: message = "購入の承認を待っています"
                        case .cancelled: message = nil
                        case .failed: message = "購入できませんでした。時間をおいてもう一度お試しください"
                        }
                    }
                } label: {
                    Text(busy ? "…" : "\(product.displayPrice) で Pro にする（買い切り）")
                }
                .buttonStyle(PrimaryButtonStyle(fill: Theme.skyDeep))
                .disabled(busy)
                Text("サブスクではありません。1 回の購入で、ずっと使えます。")
                    .font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
            }
        } else if app.store.loadState == .loading || app.store.loadState == .idle {
            ProgressView().tint(Theme.skyDeep).frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("いまは購入できません").font(Theme.text(15, .medium)).foregroundStyle(Theme.ink)
                Text("通信をたしかめて、もう一度読みこんでください").font(Theme.text(12)).foregroundStyle(Theme.inkSoft)
                Button("もう一度読みこむ") { Task { await app.store.load() } }.buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func benefit<Preview: View>(_ title: String, _ detail: String, @ViewBuilder preview: () -> Preview) -> some View {
        Slab {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(Theme.serif(18, .medium)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.text(13)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                preview()
            }
        }
    }
}
