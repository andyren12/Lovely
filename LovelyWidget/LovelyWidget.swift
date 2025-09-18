import WidgetKit
import SwiftUI
import UIKit

// MARK: - Helper Functions

func getCustomTitle(for widgetType: WidgetType) -> String {
    guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app"),
          let data = try? Data(contentsOf: sharedContainer.appendingPathComponent(widgetType.fileName)),
          let configuration = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data),
          let customTitle = configuration.customTitle else {
        return widgetType.defaultTitle
    }
    return customTitle
}

// MARK: - Widget Definitions

@available(iOS 14.0, *)
struct LovelyWidget: Widget {
    let kind: String = "LovelyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget1)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LovelyWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Widget 1")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 14.0, *)
struct DateNightWidget: Widget {
    let kind: String = "DateNightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget2)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(.purple.tertiary, for: .widget)
            } else {
                LovelyWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.purple.opacity(0.1))
            }
        }
        .configurationDisplayName("Widget 2")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 14.0, *)
struct AnniversaryWidget: Widget {
    let kind: String = "AnniversaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget3)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(.pink.tertiary, for: .widget)
            } else {
                LovelyWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.pink.opacity(0.1))
            }
        }
        .configurationDisplayName("Widget 3")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 14.0, *)
struct TravelWidget: Widget {
    let kind: String = "TravelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget4)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(.blue.tertiary, for: .widget)
            } else {
                LovelyWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.blue.opacity(0.1))
            }
        }
        .configurationDisplayName("Widget 4")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall])
    }
}

struct PhotoTimelineEntry: TimelineEntry {
    let date: Date
    let photo: UIImage?
    let eventTitle: String
    let eventDate: String
}


struct PhotoTimelineProvider: TimelineProvider {
    let widgetType: WidgetType
    typealias Entry = PhotoTimelineEntry

    init(widgetType: WidgetType = WidgetType.widget1) {
        self.widgetType = widgetType
    }

    func placeholder(in context: Context) -> PhotoTimelineEntry {
        let customTitle = getCustomTitle(for: widgetType)
        return PhotoTimelineEntry(
            date: Date(),
            photo: nil,
            eventTitle: customTitle,
            eventDate: "No events yet"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoTimelineEntry) -> ()) {
        // Try to get the custom title, fall back to default
        let customTitle = getCustomTitle(for: widgetType)
        let entry = PhotoTimelineEntry(
            date: Date(),
            photo: nil,
            eventTitle: customTitle,
            eventDate: "Preview"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoTimelineEntry>) -> ()) {
        var entries: [PhotoTimelineEntry] = []
        let currentDate = Date()

        // Load widget configuration for specific widget type
        let widgetData = loadWidgetData(for: widgetType)

        if widgetData.photos.isEmpty {
            // No photos configured - show placeholder
            let entry = PhotoTimelineEntry(
                date: currentDate,
                photo: nil,
                eventTitle: "No Events Selected",
                eventDate: "Configure in app"
            )
            entries.append(entry)
        } else {
            // Create timeline entries cycling through photos every 20 minutes
            for i in 0..<72 { // 24 hours worth of 20-minute intervals
                let entryDate = Calendar.current.date(byAdding: .minute, value: i * 20, to: currentDate)!
                let photoIndex = i % widgetData.photos.count

                let entry = PhotoTimelineEntry(
                    date: entryDate,
                    photo: widgetData.photos[photoIndex].image,
                    eventTitle: widgetData.photos[photoIndex].eventTitle,
                    eventDate: widgetData.photos[photoIndex].eventDate
                )
                entries.append(entry)
            }
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct LovelyWidgetEntryView: View {
    var entry: PhotoTimelineProvider.Entry

    var body: some View {
        ZStack {
            if let photo = entry.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .overlay(
                        // Gradient overlay for text readability
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.eventTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(entry.eventDate)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } else {
                // Placeholder when no photo is available
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.purple)

                    Text(entry.eventTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    Text(entry.eventDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Widget Data Management

func loadWidgetData(for widgetType: WidgetType = WidgetType.widget1) -> LovelyWidgetConfig {
    guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app"),
          let data = try? Data(contentsOf: sharedContainer.appendingPathComponent(widgetType.fileName)),
          let configuration = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data) else {
        return LovelyWidgetConfig(photos: [], selectedEventIds: [])
    }

    var photos: [WidgetPhotoData] = []

    for photoConfig in configuration.photos {
        if let imageData = Data(base64Encoded: photoConfig.imageBase64),
           let image = UIImage(data: imageData) {
            photos.append(WidgetPhotoData(
                image: image,
                eventTitle: photoConfig.eventTitle,
                eventDate: photoConfig.eventDate
            ))
        }
    }

    return LovelyWidgetConfig(photos: photos, selectedEventIds: configuration.selectedEventIds)
}

#Preview(as: .systemSmall) {
    LovelyWidget()
} timeline: {
    PhotoTimelineEntry(
        date: .now,
        photo: nil,
        eventTitle: "Anniversary Dinner",
        eventDate: "Last Week"
    )
}
