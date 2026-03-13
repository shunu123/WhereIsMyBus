import SwiftUI
import Combine
import Foundation
import UserNotifications
import AVFoundation
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    // Store available sounds. The empty string "" represents the default sound.
    @Published var selectedSoundName: String {
        didSet {
            UserDefaults.standard.set(selectedSoundName, forKey: "selectedAlarmSound")
        }
    }
    
    override private init() {
        self.selectedSoundName = UserDefaults.standard.string(forKey: "selectedAlarmSound") ?? ""
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }
    
    func scheduleAlarm(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        if selectedSoundName.isEmpty {
            content.sound = .default
        } else {
            // Assumes sound files (like .wav or .caf) are added to the app bundle
            // If they are not found, it falls back to default automatically by iOS in most cases
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: selectedSoundName))
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Allows notification to show even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
