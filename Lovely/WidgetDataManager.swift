import Foundation
import UIKit
import WidgetKit

class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let sharedContainerURL: URL?
    private let widgetConfigFile = "widget_photos.json"

    private init() {
        sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app")
    }

    // MARK: - Widget Configuration

    func updateWidgetConfiguration(selectedEvents: [CalendarEvent]) {
        guard let containerURL = sharedContainerURL else {
            print("❌ Failed to get shared container URL")
            return
        }

        Task {
            var widgetPhotos: [WidgetPhotoConfigData] = []

            // Process each selected event
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

            let configuration = WidgetConfigurationData(
                photos: widgetPhotos,
                selectedEventIds: selectedEvents.compactMap { $0.id },
                lastUpdated: Date()
            )

            // Save configuration to shared container
            do {
                let data = try JSONEncoder().encode(configuration)
                let fileURL = containerURL.appendingPathComponent(widgetConfigFile)
                try data.write(to: fileURL)

                // Tell WidgetKit to reload the widget
                WidgetCenter.shared.reloadTimelines(ofKind: "LovelyWidget")

                print("✅ Widget configuration updated with \(widgetPhotos.count) photos")
            } catch {
                print("❌ Failed to save widget configuration: \(error)")
            }
        }
    }

    func clearWidgetConfiguration() {
        guard let containerURL = sharedContainerURL else { return }

        let fileURL = containerURL.appendingPathComponent(widgetConfigFile)
        try? FileManager.default.removeItem(at: fileURL)

        // Reload widget to show empty state
        WidgetCenter.shared.reloadTimelines(ofKind: "LovelyWidget")

        print("✅ Widget configuration cleared")
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
}

// Note: WidgetConfigurationData and WidgetPhotoConfigData are defined in WidgetModels.swift