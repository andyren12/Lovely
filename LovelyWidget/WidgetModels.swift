import Foundation
import UIKit

// Widget-specific models that don't depend on Firebase
// These mirror the main app models but are simplified for widget use

struct WidgetCalendarEvent {
    let id: String
    let title: String
    let description: String
    let date: Date
    let photoURLs: [String]
}

// MARK: - Codable Data Structures for Widget Configuration

struct WidgetConfigurationData: Codable {
    let photos: [WidgetPhotoConfigData]
    let selectedEventIds: [String]
    let lastUpdated: Date
}

struct WidgetPhotoConfigData: Codable {
    let imageBase64: String
    let eventTitle: String
    let eventDate: String
    let eventId: String
}

// MARK: - Runtime Widget Data

struct WidgetPhotoData {
    let image: UIImage
    let eventTitle: String
    let eventDate: String
}

struct LovelyWidgetConfig {
    let photos: [WidgetPhotoData]
    let selectedEventIds: [String]
}
