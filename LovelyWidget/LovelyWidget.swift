import WidgetKit
import SwiftUI
import UIKit

@available(iOS 14.0, *)
struct LovelyWidget: Widget {
    let kind: String = "LovelyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                LovelyWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                LovelyWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Lovely Memories")
        .description("Cycles through photos from your selected events every 20 minutes")
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
    // (Optional but nice): be explicit
    typealias Entry = PhotoTimelineEntry

    func placeholder(in context: Context) -> PhotoTimelineEntry {
        PhotoTimelineEntry(
            date: Date(),
            photo: nil,
            eventTitle: "Sample Event",
            eventDate: "Today"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoTimelineEntry) -> ()) {
        let entry = PhotoTimelineEntry(
            date: Date(),
            photo: nil,
            eventTitle: "Date Night",
            eventDate: "Yesterday"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoTimelineEntry>) -> ()) {
        var entries: [PhotoTimelineEntry] = []
        let currentDate = Date()

        // Load widget configuration
        let widgetData = loadWidgetData()

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

// Fix 3: change return type to the renamed model (see file #2)
func loadWidgetData() -> LovelyWidgetConfig {
    guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app"),
          let data = try? Data(contentsOf: sharedContainer.appendingPathComponent("widget_photos.json")),
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
