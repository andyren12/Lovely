import Foundation
import MessageUI
import SwiftUI

@MainActor
class SMSManager: NSObject, ObservableObject {
    static let shared = SMSManager()

    @Published var isShowingMessageComposer = false
    @Published var messageRecipients: [String] = []
    @Published var messageBody: String = ""
    @Published var showClipboardNotification = false

    private override init() {
        super.init()
    }

    func canSendText() -> Bool {
        // Check if SMS URL scheme is available
        guard let smsURL = URL(string: "sms:") else {
            print("SMS URL scheme not available")
            return false
        }

        let canOpenSMS = UIApplication.shared.canOpenURL(smsURL)
        print("🔍 SMS Debug - Can open SMS URL: \(canOpenSMS)")

        // Additional check for simulator
        #if targetEnvironment(simulator)
        print("SMS available in simulator via URL scheme")
        return canOpenSMS
        #else
        return canOpenSMS
        #endif
    }

    func sendEventNotification(to phoneNumber: String, event: CalendarEvent, senderName: String) {
        print("🔍 SMS Debug - Attempting to send SMS to: '\(phoneNumber)'")
        print("🔍 SMS Debug - Event: '\(event.title)'")
        print("🔍 SMS Debug - Sender: '\(senderName)'")

        let eventId = event.id ?? "no-id"
        print("🔗 SMS Debug - Creating deep link for event ID: '\(eventId)'")
        let eventLink = DeepLinkManager.shared.createEventDeepLink(eventId: eventId)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = event.isAllDay ? .none : .short

        let message = """
        Hey! \(senderName) created a new event: "\(event.title)"

        📅 \(dateFormatter.string(from: event.date))
        \(event.description.isEmpty ? "" : "\n\(event.description)")

        Open event: \(eventLink)
        """

        print("🔍 SMS Debug - Message content: \(message)")
        print("🔍 SMS Debug - Deep link: \(eventLink)")

        // Use URL scheme approach instead of MFMessageComposeViewController
        sendSMSViaURL(to: phoneNumber, message: message)
    }

    private func sendSMSViaURL(to phoneNumber: String, message: String) {
        // Clean phone number (remove any formatting)
        let cleanedPhoneNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        print("🔍 SMS Debug - Original message: \(message)")

        // URL encode the message properly to preserve deep links
        guard let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode message")
            return
        }

        let smsURL = "sms:\(cleanedPhoneNumber)?body=\(encodedMessage)"
        print("🔍 SMS URL with message: \(smsURL)")

        guard let url = URL(string: smsURL) else {
            print("❌ Invalid SMS URL, falling back to clipboard method")
            fallbackToClipboard(phoneNumber: cleanedPhoneNumber, message: message)
            return
        }

        // Open the SMS app with pre-filled message
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("✅ Successfully opened SMS app with message")
                    } else {
                        print("❌ Failed to open SMS app with message, trying fallback")
                        self.fallbackToClipboard(phoneNumber: cleanedPhoneNumber, message: message)
                    }
                }
            } else {
                print("❌ Cannot open SMS URL with message, trying fallback")
                self.fallbackToClipboard(phoneNumber: cleanedPhoneNumber, message: message)
            }
        }
    }

    private func fallbackToClipboard(phoneNumber: String, message: String) {
        let smsURL = "sms:\(phoneNumber)"

        guard let url = URL(string: smsURL) else {
            print("❌ Invalid SMS URL")
            return
        }

        // Copy message to clipboard so user can paste it
        UIPasteboard.general.string = message
        print("✅ Copied message to clipboard")

        // Show notification that message was copied
        showClipboardNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showClipboardNotification = false
        }

        // Open the SMS app
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("✅ Successfully opened SMS app")
                        print("💡 Message copied to clipboard - paste in SMS")
                    } else {
                        print("❌ Failed to open SMS app")
                    }
                }
            } else {
                print("❌ Cannot open SMS URL - SMS not available")
            }
        }
    }

    func sendEventNotificationPrompt(to phoneNumber: String, event: CalendarEvent, senderName: String, onComplete: @escaping () -> Void) {
        guard canSendText() else {
            print("Device cannot send text messages")
            onComplete()
            return
        }

        let eventLink = DeepLinkManager.shared.createEventDeepLink(eventId: event.id ?? "")
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = event.isAllDay ? .none : .short

        let message = """
        Hey! \(senderName) created a new event: "\(event.title)"

        📅 \(dateFormatter.string(from: event.date))
        \(event.description.isEmpty ? "" : "\n\(event.description)")

        Tap to view: \(eventLink)
        """

        DispatchQueue.main.async {
            self.messageRecipients = [phoneNumber]
            self.messageBody = message
            self.isShowingMessageComposer = true
        }

        onComplete()
    }
}

// MessageComposeView removed - now using URL scheme approach for SMS

