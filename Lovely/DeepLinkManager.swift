import Foundation
import SwiftUI

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingEventId: String?
    @Published var shouldNavigateToEvent = false

    private init() {}

    func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme == "lovely" else { return false }

        print("Handling deep link: \(url.absoluteString)")

        switch url.host {
        case "event":
            return handleEventDeepLink(url)
        default:
            print("Unknown deep link host: \(url.host ?? "nil")")
            return false
        }
    }

    private func handleEventDeepLink(_ url: URL) -> Bool {
        // URL format: lovely://event?id=eventId
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let eventIdItem = queryItems.first(where: { $0.name == "id" }),
              let eventId = eventIdItem.value else {
            print("Invalid event deep link format")
            return false
        }

        DispatchQueue.main.async {
            self.pendingEventId = eventId
            self.shouldNavigateToEvent = true
        }

        print("Successfully parsed event ID from deep link: \(eventId)")
        return true
    }

    func createEventDeepLink(eventId: String) -> String {
        return "lovely://event?id=\(eventId)"
    }

    func clearPendingNavigation() {
        pendingEventId = nil
        shouldNavigateToEvent = false
    }
}