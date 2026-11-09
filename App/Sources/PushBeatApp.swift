import SwiftUI

@main
struct PushBeatApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                .task { await app.onLaunch() }
                .onAppear {
                    Feedback.prepare()
                    // CI のスクリーンショット用（起動引数 -screenshotScene <名前>）
                    if let scene = UserDefaults.standard.string(forKey: "screenshotScene") {
                        app.applyScreenshotScene(scene)
                    }
                }
        }
    }
}
