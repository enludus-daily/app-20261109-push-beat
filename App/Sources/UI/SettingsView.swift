import SwiftUI

/// 設定：音・振動・タイミングの調整・コース・使い方・Pro・プライバシー
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    section("音と振動") {
                        toggle("曲", "music.note", $app.progress.settings.music)
                        hairline
                        toggle("合図の音（ノーツ・触れた音）", "bell", $app.progress.settings.cues)
                        hairline
                        toggle("振動", "iphone.radiowaves.left.and.right", $app.progress.settings.haptics)
                    }
                    section("タイミングの調整") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("判定を \(abs(app.progress.settings.calibrationMs)) ms \(app.progress.settings.calibrationMs >= 0 ? "おそく" : "はやく")")
                                    .font(Theme.text(14, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                                Spacer()
                                Button("もとに戻す") { app.progress.settings.calibrationMs = 0 }
                                    .font(Theme.text(12)).foregroundStyle(Theme.skyDeep)
                            }
                            Slider(value: Binding(get: { Double(app.progress.settings.calibrationMs) },
                                                  set: { app.progress.settings.calibrationMs = Int($0.rounded()) }),
                                   in: -150...150, step: 10)
                                .tint(Theme.skyDeep)
                            Text("いつも「おそめ」と出るなら、判定をおそくすると合いやすくなります。Bluetooth のイヤホンでは音が遅れるので、＋100 ms くらいから試してください。")
                                .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    section("30 日のコース") {
                        ForEach(Course.allCases, id: \.self) { c in
                            Button {
                                if c.isPro && !app.isPro { app.sheet = .pro } else { app.progress.settings.course = c; Feedback.select() }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title).font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                                        Text(c == .starter ? "ひざつき 6 回から、30 回まで（無料）" : "20 回から 60 回。キープ・ワイド・ダイヤモンド（Pro）")
                                            .font(Theme.text(12)).foregroundStyle(Theme.inkSoft)
                                    }
                                    Spacer()
                                    if app.course == c {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.skyDeep)
                                    } else if c.isPro && !app.isPro {
                                        Image(systemName: "lock.fill").foregroundStyle(Theme.inkSoft)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if c == .starter { hairline }
                        }
                    }
                    section("Pro") {
                        if app.isPro {
                            Label("Pro を使っています", systemImage: "checkmark.seal").font(Theme.text(14, .medium)).foregroundStyle(Theme.skyDeep)
                        } else {
                            row("Pro について", "sparkles") { app.sheet = .pro }
                        }
                        hairline
                        row("購入を復元", "arrow.clockwise") { Task { await app.store.restore() } }
                    }
                    section("そのほか") {
                        row("使い方をもう一度見る", "questionmark.circle") {
                            app.progress.hasOnboarded = false
                            dismiss()
                        }
                        hairline
                        VStack(alignment: .leading, spacing: 4) {
                            Text("プライバシー").font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                            Text("記録はこの iPhone の中だけに保存し、外に送りません。カメラ・マイク・位置情報は使いません。ログインも広告もありません。")
                                .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                        hairline
                        HStack {
                            Text("バージョン").font(Theme.text(14)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                                .font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private var hairline: some View { Rectangle().fill(Theme.line).frame(height: Theme.hairline) }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(title)
            VStack(alignment: .leading, spacing: 12) { content() }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(YogaMat(corner: Theme.rCard).opacity(0.55))
                .background(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).fill(Theme.paper))
        }
    }

    private func toggle(_ title: String, _ icon: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Label(title, systemImage: icon).font(Theme.text(14)).foregroundStyle(Theme.ink)
        }
        .tint(Theme.skyDeep)
    }

    private func row(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon).font(Theme.text(14)).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
