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
                    } else if ProcessInfo.processInfo.arguments.contains("-demo") {
                        // YouTube の録画用：今日の 1 曲を自動で叩いて結果まで（README の「デモで見せる流れ」）
                        app.startDemo()
                    }
                }
        }
    }
}
