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
struct Widget1: Widget {
    let kind: String = "Widget1"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget1)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        if let photo = entry.photo {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color(.systemGray6)
                        }
                    }
            } else {
                LovelyWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Widget 1")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOS 14.0, *)
struct Widget2: Widget {
    let kind: String = "Widget2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget2)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        if let photo = entry.photo {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color(.systemGray6)
                        }
                    }
            } else {
                LovelyWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Widget 2")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOS 14.0, *)
struct Widget3: Widget {
    let kind: String = "Widget3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget3)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        if let photo = entry.photo {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color(.systemGray6)
                        }
                    }
            } else {
                LovelyWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Widget 3")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOS 14.0, *)
struct Widget4: Widget {
    let kind: String = "Widget4"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider(widgetType: WidgetType.widget4)) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        if let photo = entry.photo {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color(.systemGray6)
                        }
                    }
            } else {
                LovelyWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Widget 4")
        .description("Configure this widget in the Lovely app")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
            // Generate entries for the next 4 hours (12 intervals)
            let totalIntervals = 12 // 4 hours * 3 intervals per hour
            for i in 0..<totalIntervals {
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

        // Refresh timeline every 4 hours to ensure cycling works properly
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
}


struct LovelyWidgetEntryView: View {
    var entry: PhotoTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    private var titleFont: Font {
        switch family {
        case .systemSmall:
            return .caption
        case .systemMedium:
            return .subheadline
        case .systemLarge:
            return .headline
        default:
            return .caption
        }
    }

    private var dateFont: Font {
        switch family {
        case .systemSmall:
            return .caption2
        case .systemMedium:
            return .caption
        case .systemLarge:
            return .subheadline
        default:
            return .caption2
        }
    }

    private var textPadding: CGFloat {
        switch family {
        case .systemSmall:
            return 2
        case .systemMedium:
            return 3
        case .systemLarge:
            return 4
        default:
            return 2
        }
    }

    var body: some View {
        ZStack {
            if #available(iOS 17.0, *) {
                // For iOS 17+, photo is in containerBackground, so only show text overlay
                if entry.photo != nil {
                    VStack {
                        Spacer()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.eventTitle)
                                    .font(titleFont)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)

                                Text(entry.eventDate)
                                    .font(dateFont)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, textPadding)
                        .padding(.bottom, textPadding)
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
                }
            } else {
                // For iOS 16 and below, show photo in the main view
                if let photo = entry.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    VStack {
                        Spacer()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.eventTitle)
                                    .font(titleFont)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)

                                Text(entry.eventDate)
                                    .font(dateFont)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, textPadding)
                        .padding(.bottom, textPadding)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    Widget1()
} timeline: {
    PhotoTimelineEntry(
        date: .now,
        photo: nil,
        eventTitle: "Anniversary Dinner",
        eventDate: "Last Week"
    )
}
