import Foundation
import SwiftUI

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingEventId: String?
    @Published var shouldNavigateToEvent = false

    private init() {}

    func handleDeepLink(_ url: URL) -> Bool {
        print("🔗 DeepLinkManager - Received URL: \(url.absoluteString)")
        print("🔗 DeepLinkManager - URL scheme: '\(url.scheme ?? "nil")'")
        print("🔗 DeepLinkManager - URL host: '\(url.host ?? "nil")'")

        guard url.scheme == "lovely" else {
            print("❌ DeepLinkManager - Invalid scheme, expected 'lovely'")
            return false
        }

        print("✅ DeepLinkManager - Valid lovely:// URL detected")

        switch url.host {
        case "event":
            print("🔗 DeepLinkManager - Processing event deep link")
            return handleEventDeepLink(url)
        default:
            print("❌ DeepLinkManager - Unknown deep link host: '\(url.host ?? "nil")'")
            return false
        }
    }

    private func handleEventDeepLink(_ url: URL) -> Bool {
        // URL format: lovely://event?id=eventId
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let eventIdItem = queryItems.first(where: { $0.name == "id" }),
              let eventId = eventIdItem.value else {
            print("❌ Deep Link - Invalid event deep link format")
            print("🔗 Deep Link - URL: \(url.absoluteString)")
            return false
        }

        print("🔗 Deep Link - Successfully parsed event ID: \(eventId)")

        DispatchQueue.main.async {
            self.pendingEventId = eventId
            self.shouldNavigateToEvent = true
            print("🔗 Deep Link - Set shouldNavigateToEvent to true")
        }

        return true
    }

    func createEventDeepLink(eventId: String) -> String {
        let link = "lovely://event?id=\(eventId)"
        print("🔗 DeepLinkManager - Creating link: \(link)")
        print("🔗 DeepLinkManager - Event ID: '\(eventId)'")

        if eventId.isEmpty || eventId == "no-id" {
            print("⚠️ DeepLinkManager - WARNING: Invalid event ID!")
        }

        return link
    }

    func clearPendingNavigation() {
        pendingEventId = nil
        shouldNavigateToEvent = false
    }
}