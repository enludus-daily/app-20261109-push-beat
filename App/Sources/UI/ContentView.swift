import SwiftUI

// iPhone Duo では、内側の画面が regular × regular、外側の画面がほかの iPhone と同じ size class になる。
// 画面の大きさ・向き・機種ではなく size class で並べ方を変える（Apple「Preparing your app for iPhone Duo」）。
struct ContentView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            if !app.progress.hasOnboarded {
                OnboardingView().transition(.opacity)
            } else {
                switch app.route {
                case .home:
                    HomeView().transition(.opacity)
                case .play:
                    if let g = app.game {
                        PlayView(game: g).id(ObjectIdentifier(g)).transition(.opacity)
                    } else {
                        HomeView()
                    }
                case .result:
                    if let r = app.lastResult { ResultView(result: r).transition(.opacity) } else { HomeView() }
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: app.route)
        .sheet(item: $app.sheet) { sheet in
            Group {
                switch sheet {
                case .songs: SongsView()
                case .records: RecordsView()
                case .settings: SettingsView()
                case .pro: ProView()
                case .techniques: TechniquesView()
                case .baseline: BaselineView()
                }
            }
            .environment(app)
        }
        // 淡いトーンの世界観（マット・レコード）をそのまま見せるため、明るい見た目に固定する（StudyReel と同じ）
        .preferredColorScheme(.light)
    }
}
