import UserNotifications

// Not final — subclassed by SpyNotificationService in tests
class NotificationService {
    static let shared = NotificationService()
    init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification-Berechtigung Fehler: \(error)")
            }
        }
    }

    func send(title: String, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body = body, !body.isEmpty {
            content.body = body
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification-Fehler: \(error)")
            }
        }
    }
}
