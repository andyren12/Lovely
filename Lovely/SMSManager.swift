import Foundation
import MessageUI
import SwiftUI

@MainActor
class SMSManager: NSObject, ObservableObject {
    static let shared = SMSManager()

    @Published var isShowingMessageComposer = false
    @Published var messageRecipients: [String] = []
    @Published var messageBody: String = ""

    private override init() {
        super.init()
    }

    func canSendText() -> Bool {
        return MFMessageComposeViewController.canSendText()
    }

    func sendEventNotification(to phoneNumber: String, event: CalendarEvent, senderName: String) {
        guard canSendText() else {
            print("Device cannot send text messages")
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

        messageRecipients = [phoneNumber]
        messageBody = message
        isShowingMessageComposer = true
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

struct MessageComposeView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    let recipients: [String]
    let body: String
    let onComplete: (() -> Void)?

    init(isShowing: Binding<Bool>, recipients: [String], body: String, onComplete: (() -> Void)? = nil) {
        self._isShowing = isShowing
        self.recipients = recipients
        self.body = body
        self.onComplete = onComplete
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        composer.recipients = recipients
        composer.body = body
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposeView

        init(_ parent: MessageComposeView) {
            self.parent = parent
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            switch result {
            case .sent:
                print("Message sent successfully")
            case .cancelled:
                print("Message cancelled")
            case .failed:
                print("Message failed to send")
            @unknown default:
                print("Unknown message result")
            }

            parent.isShowing = false
            parent.onComplete?()
        }
    }
}