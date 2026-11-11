import QuartzCore
import SwiftUI

/// はじめの 3 ページ。動く見本（輪が近づいて重なる・頭が下りて触れる）で見せる。ページ送りは自前（TabView の page は使わない）
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var demoRunning = false
    @State private var demoRun = 0

    private let pages: [(caption: String, title: String, body: String)] = [
        ("Push Beat", "腕立てが、\n音ゲーになる。", "輪がレコードに重なる瞬間に、体を下ろして画面に触れる。拍に合うと Perfect。数えなくても、曲が終われば今日の分。"),
        ("置き方", "床に置いて、\n鼻かあごで触れる。", "画面の上側に頭がくるように置く。どこに触れても 1 回。下で止まる「キープ」は、触れたまま拍を待つ。"),
        ("自分に合わせる", "回数も、やり方も、\n自分で決める。", "いまの自分の回数から 30 日の道を作り、毎回の結果で次の回数を提案します。胸・二の腕・肩・体幹から、今日のやり方を選べます。記録はこの iPhone の中だけ。カメラもマイクも使いません。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("スキップ") { finish() }.font(Theme.text(14)).foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            // 見本は 3 回くり返したら止まる（止まったら重なった瞬間の絵。触れるともう一度）。
            // 動き続ける画面を作らない（電池と、CI の撮影で右上に黒い丸が出た件の切り分け。監督のレビュー #12）
            TimelineView(.animation(paused: reduceMotion || !demoRunning)) { _ in
                demo(time: reduceMotion || !demoRunning ? 1.68 : CACurrentMediaTime())
            }
            .contentShape(Rectangle())
            .onTapGesture { demoRun += 1 }
            .task(id: "\(page)-\(demoRun)") {
                demoRunning = !reduceMotion
                try? await Task.sleep(for: .seconds(7.2))
                demoRunning = false
            }
            .frame(maxWidth: 340, maxHeight: 340)
            .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 12) {
                Caption(pages[page].caption, color: Theme.skyDeep)
                Text(pages[page].title).font(Theme.serif(32, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pages[page].body).font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 24)
            .id(page)
            .transition(.opacity)

            Spacer(minLength: 12)
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule().fill(i == page ? Theme.skyDeep : Theme.line).frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .padding(.bottom, 16)
            .accessibilityHidden(true)
            Button(page == pages.count - 1 ? "はじめる" : "次へ") {
                if page < pages.count - 1 {
                    withAnimation(.easeOut(duration: 0.25)) { page += 1 }
                    Feedback.select()
                } else {
                    finish()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.bottom, page == pages.count - 1 ? 8 : 24)
            if page == pages.count - 1 {
                Button("まず指でためす（4 回）") { app.startPractice() }
                    .buttonStyle(QuietButtonStyle())
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .background(Theme.ground.ignoresSafeArea())
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.35)) { app.progress.hasOnboarded = true }
    }

    /// 見本の動き（2.4 秒でくり返す。時刻から計算するので repeatForever を使わない）
    @ViewBuilder
    private func demo(time: Double) -> some View {
        let cycle = 2.4
        let p = time.truncatingRemainder(dividingBy: cycle) / cycle  // 0〜1
        switch page {
        case 1:
            // 頭が下りて触れる
            let drop = p < 0.5 ? p / 0.5 : 1 - (p - 0.5) / 0.5
            PlacementSketch(headDrop: CGFloat(drop))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.paper))
        default:
            // 輪が近づいて、重なった瞬間に波紋と Perfect
            GeometryReader { geo in
                let d = min(geo.size.width, geo.size.height) * 0.72
                let approach = min(1, p / 0.6)  // 0.6 で重なる
                ZStack {
                    YogaMat(corner: 28)
                    RecordDisc(label: page == 0 ? "Morning Latte" : "Day 1", angle: .degrees(p * 360)).frame(width: d, height: d)
                    if p < 0.6 {
                        Circle().stroke(Theme.skyDeep, lineWidth: 5)
                            .frame(width: d * 1.04 * (1 + 0.7 * (1 - approach)), height: d * 1.04 * (1 + 0.7 * (1 - approach)))
                            .opacity(0.45 + 0.55 * approach)
                    } else {
                        let q = (p - 0.6) / 0.4
                        Circle().stroke(Theme.peachDeep, lineWidth: 3 * (1 - q) + 0.5)
                            .frame(width: d * (1.04 + 0.35 * q), height: d * (1.04 + 0.35 * q))
                            .opacity(1 - q)
                        Text("Perfect").font(Theme.serif(30, .medium).italic()).foregroundStyle(Theme.peachDeep)
                            .padding(.horizontal, 12).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.paper.opacity(0.92)))
                            .opacity(q < 0.7 ? 1 : (1 - q) / 0.3)
                            .offset(y: -(min(geo.size.width, geo.size.height) / 2 - 30))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}
