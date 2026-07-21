//
//  PetNotificationScheduler.swift
//  PetApp  <-- app target, NOT the widget extension
//
//  The "Banner" mockup is a plain local notification, not a widget. Call
//  requestAuthorizationIfNeeded() once during onboarding, then
//  scheduleMorningQuestionNotification() each time a new daily question
//  is ready.
//

import UserNotifications

enum PetNotificationScheduler {

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Matches: "Pet — Good morning! I have a new question for you today 💜"
    static func scheduleMorningQuestionNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Pet"
        content.body = "Good morning! I have a new question for you today 💜"
        content.sound = .default
        content.userInfo = ["route": "question"]

        var components = Calendar.current.dateComponents([.hour, .minute], from: date)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "morningQuestion",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Matches the "Feed me!" reminder shown on the lock screen widget/Live Activity.
    static func scheduleFeedReminder(after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Pet"
        content.body = "I'm getting hungry — got a minute to feed me?"
        content.sound = .default
        content.userInfo = ["route": "feed"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "feedReminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
