import Foundation
import UIKit
import SwiftUI

// Widget-specific models that don't depend on Firebase
// These mirror the main app models but are simplified for widget use

// MARK: - Widget Types

enum WidgetType: String, CaseIterable {
    case widget1 = "widget1"
    case widget2 = "widget2"
    case widget3 = "widget3"
    case widget4 = "widget4"

    var fileName: String {
        return "widget_photos_\(rawValue).json"
    }

    func fileName(for userId: String) -> String {
        return "widget_photos_\(rawValue)_\(userId).json"
    }

    var defaultTitle: String {
        switch self {
        case .widget1: return "Widget 1"
        case .widget2: return "Widget 2"
        case .widget3: return "Widget 3"
        case .widget4: return "Widget 4"
        }
    }

    var icon: String {
        switch self {
        case .widget1: return "heart.fill"
        case .widget2: return "wineglass"
        case .widget3: return "gift.fill"
        case .widget4: return "airplane"
        }
    }

    var color: Color {
        switch self {
        case .widget1: return .purple
        case .widget2: return .pink
        case .widget3: return .red
        case .widget4: return .blue
        }
    }
}

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
    let customTitle: String?
    let customIcon: String?
    let customColorName: String?
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

