import SwiftUI

/// 曲の棚：レコードのジャケットが並ぶ。選ぶと、譜面の形と回数を決めて遊べる
struct SongsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    shelf(L("無料の 6 曲"), Songbook.free)
                    shelf(L("Pro の 12 曲"), Songbook.pro)
                }
                .padding(18)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(L("曲をえらぶ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("とじる"), systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { id in
                if let song = Songbook.song(id) { SongDetail(song: song) }
            }
        }
    }

    private func shelf(_ title: String, _ songs: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(title)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: hSize == .regular ? 4 : 2), spacing: 18) {
                ForEach(songs) { song in
                    NavigationLink(value: song.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            Jacket(song: song, locked: song.isPro && !app.isPro)
                            Text(song.title).font(Theme.text(14, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                            HStack(spacing: 6) {
                                LevelDots(level: song.level)
                                Text("BPM \(Int(song.bpm))").font(Theme.label(10)).foregroundStyle(Theme.inkSoft)
                                if song.hasKeep { Text(L("キープ")).font(Theme.label(10)).foregroundStyle(Theme.peachDeep) }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("%@、むずかしさ %@%@", "\(song.title)", "\(song.level)", "\(song.isPro && !app.isPro ? L("、Pro") : "")"))
                }
            }
        }
    }
}

private struct SongDetail: View {
    @Environment(AppModel.self) private var app
    let song: Song
    @State private var reps = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Jacket(song: song).frame(width: 150)
                        .rotationEffect(.degrees(-3))
                    VStack(alignment: .leading, spacing: 6) {
                        Caption(song.english)
                        Text(song.title).font(Theme.serif(26, .medium)).foregroundStyle(Theme.ink)
                        LevelDots(level: song.level)
                        Text(L("BPM %@ ・ %@", "\(Int(song.bpm))", "\(song.mood.label)")).font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                        Text(song.line).font(Theme.text(14)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Slab {
                    VStack(alignment: .leading, spacing: 10) {
                        Caption(L("譜面の形（はじめの 16 拍）"))
                        PatternStrip(song: song)
                        HStack(spacing: 14) {
                            legend(Theme.skyDeep, L("タッチ"))
                            legend(Theme.peachDeep, L("キープ（下で止まる）"))
                        }
                    }
                }
                Slab {
                    VStack(alignment: .leading, spacing: 10) {
                        Caption(L("回数"))
                        HStack(spacing: 8) {
                            ForEach([10, 20, 30, 40], id: \.self) { n in
                                Button { reps = n; Feedback.select() } label: {
                                    Text("\(n)").font(Theme.serif(20, .medium)).monospacedDigit()
                                        .foregroundStyle(reps == n ? .white : Theme.ink)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(RoundedRectangle(cornerRadius: Theme.rMid, style: .continuous).fill(reps == n ? Theme.skyDeep : Theme.skyMist))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(L("%@ 回", "\(n)"))
                                .accessibilityAddTraits(reps == n ? .isSelected : [])
                            }
                        }
                    }
                }
                actions
            }
            .padding(18)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var actions: some View {
        let locked = song.isPro && !app.isPro
        if locked && app.progress.usedProTrial {
            Text(L("Pro の曲は、Pro で遊べます（お試しの 1 回は使いました）")).font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
            Button(L("Pro を見る")) { app.sheet = .pro }.buttonStyle(PrimaryButtonStyle())
        } else {
            if locked {
                Text(L("Pro の曲を 1 回だけ、無料で試せます")).font(Theme.text(13)).foregroundStyle(Theme.peachDeep)
            }
            Button(locked ? L("1 回だけ試す") : L("この曲で %@ 回（%@）", "\(reps)", "\(app.todayTechnique.title)")) {
                app.start(PlayRequest(song: song, reps: reps, technique: app.todayTechnique))
            }
            .buttonStyle(PrimaryButtonStyle())
            if !locked {
                Button(L("エンドレスで遊ぶ（3 回続けて外すまで）")) { app.startEndless(song: song) }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func legend(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(s).font(Theme.label(11)).foregroundStyle(Theme.inkSoft)
        }
    }
}

/// 譜面のはじめの 16 拍を、点と帯で見せる
struct PatternStrip: View {
    let song: Song

    var body: some View {
        let chart = song.chart(reps: 12)
        Canvas { ctx, size in
            let beats = 16.0
            let step = size.width / beats
            for b in 0..<16 {
                let x = CGFloat(b) * step + step / 2
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: size.height / 2 - 1.5, width: 3, height: 3)), with: .color(Theme.line))
            }
            for note in chart.notes {
                let b = note.beat - Double(Chart.countIn)
                guard b < beats else { break }
                let x = CGFloat(b) * step + step / 2
                switch note.kind {
                case .tap:
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 7, y: size.height / 2 - 7, width: 14, height: 14)), with: .color(Theme.skyDeep))
                case .keep(let n):
                    let len = CGFloat(n) * step
                    ctx.fill(Path(roundedRect: CGRect(x: x - 7, y: size.height / 2 - 7, width: len, height: 14), cornerRadius: 7), with: .color(Theme.peachDeep))
                }
            }
        }
        .frame(height: 24)
        .accessibilityHidden(true)
    }
}
