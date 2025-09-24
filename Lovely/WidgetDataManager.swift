import Foundation
import UIKit
import WidgetKit

// MARK: - Widget Data Structures

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

class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let sharedContainerURL: URL?

    private init() {
        sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app")
    }

    // MARK: - Widget Configuration

    func updateWidgetConfiguration(selectedEvents: [CalendarEvent], for widgetType: WidgetType = .widget1, userId: String? = nil) {
        guard let containerURL = sharedContainerURL else {
            print("❌ Failed to get shared container URL")
            return
        }

        Task { @MainActor in
            var widgetPhotos: [WidgetPhotoConfigData] = []

            // Process all selected events (no filtering)
            for event in selectedEvents {
                // Only include events with photos
                guard !event.photoURLs.isEmpty else { continue }

                // Download and compress photos for widget use
                for photoKey in event.photoURLs.prefix(3) { // Limit to 3 photos per event for storage
                    if let image = await downloadAndCompressPhoto(key: photoKey) {
                        let compressedData = image.jpegData(compressionQuality: 0.6) ?? Data()
                        let base64String = compressedData.base64EncodedString()

                        widgetPhotos.append(WidgetPhotoConfigData(
                            imageBase64: base64String,
                            eventTitle: event.title,
                            eventDate: formatEventDate(event.date),
                            eventId: event.id ?? ""
                        ))
                    }
                }
            }

            // Limit total photos to prevent memory issues
            let maxPhotos = 20
            if widgetPhotos.count > maxPhotos {
                widgetPhotos = Array(widgetPhotos.prefix(maxPhotos))
            }

            // Load existing configuration to preserve custom title, icon, and color
            let fileName = userId != nil ? widgetType.fileName(for: userId!) : widgetType.fileName
            let fileURL = containerURL.appendingPathComponent(fileName)
            let existingTitle: String?
            let existingIcon: String?
            let existingColor: String?
            if let data = try? Data(contentsOf: fileURL),
               let existingConfig = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data) {
                existingTitle = existingConfig.customTitle
                existingIcon = existingConfig.customIcon
                existingColor = existingConfig.customColorName
            } else {
                existingTitle = nil
                existingIcon = nil
                existingColor = nil
            }

            let configuration = WidgetConfigurationData(
                photos: widgetPhotos,
                selectedEventIds: selectedEvents.compactMap { $0.id },
                lastUpdated: Date(),
                customTitle: existingTitle,
                customIcon: existingIcon,
                customColorName: existingColor
            )

            // Save configuration to shared container
            do {
                let data = try JSONEncoder().encode(configuration)
                try data.write(to: fileURL)

                // Tell WidgetKit to reload the specific widget
                WidgetCenter.shared.reloadTimelines(ofKind: getWidgetKind(for: widgetType))

                print("✅ \(widgetType.defaultTitle) widget configuration updated with \(widgetPhotos.count) photos")
            } catch {
                print("❌ Failed to save \(widgetType.defaultTitle) widget configuration: \(error)")
            }
        }
    }

    func clearWidgetConfiguration(for widgetType: WidgetType = .widget1, userId: String? = nil) {
        guard let containerURL = sharedContainerURL else { return }

        let fileName = userId != nil ? widgetType.fileName(for: userId!) : widgetType.fileName
        let fileURL = containerURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)

        // Reload widget to show empty state
        WidgetCenter.shared.reloadTimelines(ofKind: getWidgetKind(for: widgetType))

        print("✅ \(widgetType.defaultTitle) widget configuration cleared")
    }

    func clearAllWidgetConfigurations() {
        for widgetType in WidgetType.allCases {
            clearWidgetConfiguration(for: widgetType)
        }
    }

    func updateAllWidgetTypes(with selectedEvents: [CalendarEvent]) {
        for widgetType in WidgetType.allCases {
            updateWidgetConfiguration(selectedEvents: selectedEvents, for: widgetType)
        }
    }

    // MARK: - Widget Title Management

    func setWidgetTitle(_ title: String, for widgetType: WidgetType, userId: String? = nil) {
        guard let containerURL = sharedContainerURL else { return }

        let fileName = userId != nil ? widgetType.fileName(for: userId!) : widgetType.fileName
        let fileURL = containerURL.appendingPathComponent(fileName)

        // Load existing configuration or create new one
        var configuration: WidgetConfigurationData
        if let data = try? Data(contentsOf: fileURL),
           let existingConfig = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data) {
            configuration = WidgetConfigurationData(
                photos: existingConfig.photos,
                selectedEventIds: existingConfig.selectedEventIds,
                lastUpdated: Date(),
                customTitle: title,
                customIcon: existingConfig.customIcon,
                customColorName: existingConfig.customColorName
            )
        } else {
            configuration = WidgetConfigurationData(
                photos: [],
                selectedEventIds: [],
                lastUpdated: Date(),
                customTitle: title,
                customIcon: nil,
                customColorName: nil
            )
        }

        // Save updated configuration
        do {
            let data = try JSONEncoder().encode(configuration)
            try data.write(to: fileURL)
            WidgetCenter.shared.reloadTimelines(ofKind: getWidgetKind(for: widgetType))
        } catch {
            print("❌ Failed to save widget title: \(error)")
        }
    }

    func setWidgetIcon(_ icon: String, for widgetType: WidgetType, userId: String? = nil) {
        guard let containerURL = sharedContainerURL else { return }

        let fileName = userId != nil ? widgetType.fileName(for: userId!) : widgetType.fileName
        let fileURL = containerURL.appendingPathComponent(fileName)

        // Load existing configuration or create new one
        var configuration: WidgetConfigurationData
        if let data = try? Data(contentsOf: fileURL),
           let existingConfig = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data) {
            configuration = WidgetConfigurationData(
                photos: existingConfig.photos,
                selectedEventIds: existingConfig.selectedEventIds,
                lastUpdated: Date(),
                customTitle: existingConfig.customTitle,
                customIcon: icon,
                customColorName: existingConfig.customColorName
            )
        } else {
            configuration = WidgetConfigurationData(
                photos: [],
                selectedEventIds: [],
                lastUpdated: Date(),
                customTitle: nil,
                customIcon: icon,
                customColorName: nil
            )
        }

        // Save updated configuration
        do {
            let data = try JSONEncoder().encode(configuration)
            try data.write(to: fileURL)
            WidgetCenter.shared.reloadTimelines(ofKind: getWidgetKind(for: widgetType))
        } catch {
            print("❌ Failed to save widget icon: \(error)")
        }
    }

    func getWidgetTitle(for widgetType: WidgetType, userId: String? = nil) -> String {
        guard let containerURL = sharedContainerURL else { return widgetType.defaultTitle }

        let fileName = userId != nil ? widgetType.fileName(for: userId!) : widgetType.fileName
        let fileURL = containerURL.appendingPathComponent(fileName)

        if let data = try? Data(contentsOf: fileURL),
           let configuration = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data),
           let customTitle = configuration.customTitle {
            return customTitle
        }

        return widgetType.defaultTitle
    }

    func getWidgetIcon(for widgetType: WidgetType, userId: String? = nil) -> String {
        guard let containerURL = sharedContainerURL else { return widgetType.icon }

        let fileName = userId != nil ? widgetType.fileName(for: userId!) : widgetType.fileName
        let fileURL = containerURL.appendingPathComponent(fileName)

        if let data = try? Data(contentsOf: fileURL),
           let configuration = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data),
           let customIcon = configuration.customIcon {
            return customIcon
        }

        return widgetType.icon
    }

    // MARK: - Helper Methods

    private func downloadAndCompressPhoto(key: String) async -> UIImage? {
        do {
            let signedURL = try await S3Manager.shared.getSignedURL(for: key)
            let (data, _) = try await URLSession.shared.data(from: signedURL)

            if let image = UIImage(data: data) {
                // Compress image for widget storage
                return resizeImageForWidget(image)
            }
        } catch {
            print("❌ Failed to download photo for widget: \(error)")
        }
        return nil
    }

    private func resizeImageForWidget(_ image: UIImage) -> UIImage? {
        // Resize to widget dimensions (small widget is ~158x158 points on most devices)
        let targetSize = CGSize(width: 158, height: 158)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }


    // Helper method to get widget kind string
    private func getWidgetKind(for widgetType: WidgetType) -> String {
        switch widgetType {
        case .widget1: return "Widget1"
        case .widget2: return "Widget2"
        case .widget3: return "Widget3"
        case .widget4: return "Widget4"
        }
    }
}