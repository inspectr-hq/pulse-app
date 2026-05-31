import Foundation
import UserNotifications

protocol NotificationDispatching {
    func send(title: String, body: String)
}

final class NotificationCenterDispatcher: NotificationDispatching {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func send(title: String, body: String) {
        center.getNotificationSettings { [weak center] settings in
            guard let center else { return }

            let schedule: () -> Void = {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        schedule()
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }
}
