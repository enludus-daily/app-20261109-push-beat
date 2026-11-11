import SwiftUI
import UIKit

/// 設定：音・振動・タイミングの調整・コース・使い方・Pro・プライバシー
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var reminderDenied = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    section(L("回数")) {
                        row(app.progress.baseline.map { L("いまの自分の回数：%@ 回", "\($0)") } ?? L("いまの自分の回数を決める"), "figure.strengthtraining.traditional") {
                            app.sheet = .baseline
                        }
                        hairline
                        HStack {
                            Text(app.progress.repShift == 0 ? L("回数の調整：なし") : L("回数の調整：%@%@ 回", "\(app.progress.repShift > 0 ? "+" : "")", "\(app.progress.repShift)"))
                                .font(Theme.text(14)).monospacedDigit().foregroundStyle(Theme.ink)
                            Spacer()
                            if app.progress.repShift != 0 {
                                Button(L("もとに戻す")) { app.progress.repShift = 0 }
                                    .font(Theme.text(12)).foregroundStyle(Theme.skyDeep)
                            }
                        }
                        Text(L("ホームの −／＋ と、結果の画面の提案で動いた分です。いまの自分の回数を決め直すと 0 に戻ります。"))
                            .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    section(L("音と振動")) {
                        toggle(L("曲"), "music.note", $app.progress.settings.music)
                        hairline
                        toggle(L("合図の音（ノーツ・触れた音）"), "bell", $app.progress.settings.cues)
                        hairline
                        toggle(L("振動"), "iphone.radiowaves.left.and.right", $app.progress.settings.haptics)
                    }
                    section(L("毎日のお知らせ")) {
                        Toggle(isOn: Binding(get: { app.progress.settings.reminder }, set: { setReminder($0) })) {
                            Label(L("毎日 ") + String(app.progress.settings.reminderHour) + L(" 時にお知らせ"), systemImage: "bell.badge")
                                .font(Theme.text(14)).foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.skyDeep)
                        if app.progress.settings.reminder {
                            HStack(spacing: 8) {
                                ForEach([7, 12, 18, 21], id: \.self) { h in
                                    Button { app.progress.settings.reminderHour = h; setReminder(true) } label: {
                                        Text(L("%@ 時", "\(h)")).font(Theme.text(13, .medium))
                                            .foregroundStyle(app.progress.settings.reminderHour == h ? .white : Theme.ink)
                                            .frame(maxWidth: .infinity, minHeight: 36)
                                            .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous)
                                                .fill(app.progress.settings.reminderHour == h ? Theme.skyDeep : Theme.skyMist))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if reminderDenied {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("通知が許可されていません。設定アプリの「通知」で許可すると、お知らせが届きます。"))
                                    .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                                Button(L("設定アプリを開く")) {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }
                                .font(Theme.text(13, .medium)).foregroundStyle(Theme.skyDeep)
                            }
                        }
                    }
                    section(L("タイミングの調整")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(Self.calibrationLabel(app.progress.settings.calibrationMs))
                                    .font(Theme.text(14, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                                Spacer()
                                Button(L("もとに戻す")) { app.progress.settings.calibrationMs = 0 }
                                    .font(Theme.text(12)).foregroundStyle(Theme.skyDeep)
                            }
                            Slider(value: Binding(get: { Double(app.progress.settings.calibrationMs) },
                                                  set: { app.progress.settings.calibrationMs = Int($0.rounded()) }),
                                   in: -150...150, step: 10)
                                .tint(Theme.skyDeep)
                            Text(L("いつも「おそめ」と出るなら、判定をおそくすると合いやすくなります。Bluetooth のイヤホンでは音が遅れるので、＋100 ms くらいから試してください。"))
                                .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    section(L("30 日のコース")) {
                        ForEach(Course.allCases, id: \.self) { c in
                            Button {
                                if c.isPro && !app.isPro { app.sheet = .pro } else { app.progress.settings.course = c; Feedback.select() }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title).font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                                        Text(c == .starter ? L("ひざつきから、ふつうへ（無料）") : L("回数多め。ワイド・ダイヤモンド・キープの日（Pro）"))
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
                            Label(L("Pro を使っています"), systemImage: "checkmark.seal").font(Theme.text(14, .medium)).foregroundStyle(Theme.skyDeep)
                        } else {
                            row(L("Pro について"), "sparkles") { app.sheet = .pro }
                        }
                        hairline
                        row(L("購入を復元"), "arrow.clockwise") { Task { await app.store.restore() } }
                    }
                    section(L("そのほか")) {
                        row(L("使い方をもう一度見る"), "questionmark.circle") {
                            app.progress.hasOnboarded = false
                            dismiss()
                        }
                        hairline
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("プライバシー")).font(Theme.text(14, .medium)).foregroundStyle(Theme.ink)
                            Text(L("記録はこの iPhone の中だけに保存し、外に送りません。カメラ・マイク・位置情報は使いません。ログインも広告もありません。"))
                                .font(Theme.text(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                        hairline
                        HStack {
                            Text(L("バージョン")).font(Theme.text(14)).foregroundStyle(Theme.ink)
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
            .navigationTitle(L("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("とじる"), systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    static func calibrationLabel(_ ms: Int) -> String {
        if ms == 0 { return L("調整なし") }
        let direction: String = ms > 0 ? L("おそく") : L("はやく")
        return L("判定を ") + String(abs(ms)) + " ms " + direction
    }

    private func setReminder(_ on: Bool) {
        guard on else {
            app.progress.settings.reminder = false
            Reminder.cancel()
            return
        }
        let hour = app.progress.settings.reminderHour
        Task {
            let outcome = await Reminder.schedule(hour: hour)
            reminderDenied = outcome == .denied
            app.progress.settings.reminder = outcome == .scheduled
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
