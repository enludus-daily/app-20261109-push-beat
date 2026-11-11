import UserNotifications

/// 毎日のお知らせ（自分で設定でオンにしたときだけ。端末の中で予約し、外に送らない）
enum Reminder {
    static let id = "daily-push-beat"

    enum Outcome: Equatable { case scheduled, denied }

    /// 許可をたずね、毎日 hour 時に 1 回のお知らせを予約する
    static func schedule(hour: Int) async -> Outcome {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return .denied }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = L("今日の 1 曲")
        content.body = L("床に置いて、3 分だけ。拍に合わせて腕立てを。")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return .scheduled
        } catch {
            return .denied
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
