import SwiftUI

// MARK: - Widget Types

enum WidgetType: String, CaseIterable {
    case widget1 = "widget1"
    case widget2 = "widget2"
    case widget3 = "widget3"
    case widget4 = "widget4"

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

    var fileName: String {
        return "widget_photos_\(rawValue).json"
    }

}

// MARK: - Sheet Management

enum SheetType: Identifiable {
    case eventSelection(WidgetType)
    case widgetPreview(WidgetType?)

    var id: String {
        switch self {
        case .eventSelection(let type): return "eventSelection_\(type.rawValue)"
        case .widgetPreview(let type): return "widgetPreview_\(type?.rawValue ?? "all")"
        }
    }
}

struct WidgetsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedWidgetType: WidgetType?
    @State private var selectedEvents: Set<String> = []
    @State private var showingWidgetPreview = false
    @State private var showingEventSelection = false
    @State private var hasLoadedEvents = false

    var availableEvents: [CalendarEvent] {
        calendarManager.events.filter { !$0.photoURLs.isEmpty }
    }

    var body: some View {
        Group {
            if userSession.isLoading || userManager.isLoading || calendarManager.isLoading {
                ProgressView("Loading...")
            } else if !userSession.isInCouple {
                noCoupleView
            } else if availableEvents.isEmpty {
                noEventsView
            } else {
                widgetTypesView
            }
        }
        .onAppear {
            if !hasLoadedEvents || calendarManager.events.isEmpty {
                loadEvents()
            }
        }
        .onChange(of: userSession.coupleId) { _, _ in
            hasLoadedEvents = false
            loadEvents()
        }
        .sheet(item: Binding<SheetType?>(
            get: {
                if showingEventSelection, let widgetType = selectedWidgetType {
                    return .eventSelection(widgetType)
                } else if showingWidgetPreview {
                    return .widgetPreview(selectedWidgetType)
                }
                return nil
            },
            set: { newValue in
                showingEventSelection = false
                showingWidgetPreview = false
                if case .eventSelection = newValue {
                    showingEventSelection = true
                } else if case .widgetPreview = newValue {
                    showingWidgetPreview = true
                }
            }
        )) { sheetType in
            switch sheetType {
            case .eventSelection(let widgetType):
                WidgetEventSelectionView(
                    widgetType: widgetType,
                    availableEvents: availableEvents,
                    onConfigure: { events in
                        WidgetDataManager.shared.updateWidgetConfiguration(selectedEvents: events, for: widgetType)
                        showingEventSelection = false
                        showingWidgetPreview = true
                    }
                )
            case .widgetPreview(let widgetType):
                WidgetPreviewView(widgetType: widgetType, events: availableEvents)
            }
        }
    }

    private var widgetTypesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Widget Types")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Create custom widgets for your home screen. Each widget can be configured with your chosen events.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                }
                .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(WidgetType.allCases, id: \.self) { widgetType in
                        WidgetTypeCard(
                            widgetType: widgetType,
                            availableEvents: availableEvents
                        ) {
                            selectedWidgetType = widgetType
                            showingEventSelection = true
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }


    private var noCoupleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Partner Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You need to create or join a couple to create widgets from your shared events")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Events with Photos")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You have \(calendarManager.events.count) total events, but none have photos yet. Add photos to your events in the Calendar tab to create widgets.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                loadEvents()
            }
            .font(.subheadline)
            .foregroundColor(.purple)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadEvents() {
        guard let coupleId = userSession.coupleId else { return }

        Task {
            await calendarManager.loadEventsWithCache(for: coupleId)
            await MainActor.run {
                hasLoadedEvents = true
            }
        }
    }

    private func toggleEventSelection(_ event: CalendarEvent) {
        guard let eventId = event.id else { return }

        if selectedEvents.contains(eventId) {
            selectedEvents.remove(eventId)
        } else {
            selectedEvents.insert(eventId)
        }
    }

    private func configureAllWidgets() {
        WidgetDataManager.shared.updateAllWidgetTypes(with: availableEvents)
        showingWidgetPreview = true
    }
}

struct WidgetTypeCard: View {
    let widgetType: WidgetType
    let availableEvents: [CalendarEvent]
    let onConfigure: () -> Void

    @State private var customTitle: String = ""
    @State private var isEditingTitle = false
    @State private var showingTitleEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: widgetType.icon)
                    .font(.title2)
                    .foregroundColor(widgetType.color)

                Spacer()

                Button {
                    showingTitleEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("\(availableEvents.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(customTitle.isEmpty ? widgetType.defaultTitle : customTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Spacer()

            Button("Configure") {
                onConfigure()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(widgetType.color)
            .cornerRadius(8)
        }
        .padding()
        .frame(height: 160)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            customTitle = WidgetDataManager.shared.getWidgetTitle(for: widgetType)
        }
        .sheet(isPresented: $showingTitleEditor) {
            TitleEditorView(
                currentTitle: customTitle.isEmpty ? widgetType.defaultTitle : customTitle,
                widgetType: widgetType
            ) { newTitle in
                customTitle = newTitle
                WidgetDataManager.shared.setWidgetTitle(newTitle, for: widgetType)
            }
        }
    }
}

struct WidgetEventSelectionView: View {
    let widgetType: WidgetType
    let availableEvents: [CalendarEvent]
    let onConfigure: ([CalendarEvent]) -> Void

    @State private var selectedEvents: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    private var filteredEvents: [CalendarEvent] {
        availableEvents
    }

    var body: some View {
        NavigationView {
            VStack {
                if filteredEvents.isEmpty {
                    noMatchingEventsView
                } else {
                    eventSelectionView
                }
            }
            .navigationTitle(WidgetDataManager.shared.getWidgetTitle(for: widgetType))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Configure") {
                        let eventsToUse = filteredEvents.filter { event in
                            selectedEvents.contains(event.id ?? "")
                        }
                        onConfigure(eventsToUse)
                        dismiss()
                    }
                    .disabled(selectedEvents.isEmpty)
                }
            }
            .onAppear {
                // Start with no events selected
                selectedEvents = []
            }
        }
    }

    private var eventSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Found \(filteredEvents.count) matching events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Configure this widget with your chosen events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            List {
                ForEach(filteredEvents) { event in
                    EventSelectionRow(
                        event: event,
                        isSelected: selectedEvents.contains(event.id ?? "")
                    ) {
                        toggleEventSelection(event)
                    }
                }
            }
            .listStyle(PlainListStyle())

            if !selectedEvents.isEmpty {
                HStack {
                    Text("\(selectedEvents.count) event\(selectedEvents.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Select All") {
                        selectedEvents = Set(filteredEvents.compactMap { $0.id })
                    }
                    .font(.subheadline)
                    .foregroundColor(widgetType.color)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    private var noMatchingEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: widgetType.icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Matching Events")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create events with titles containing keywords like \"\(getSampleKeywords())\" to use this widget type")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func toggleEventSelection(_ event: CalendarEvent) {
        guard let eventId = event.id else { return }

        if selectedEvents.contains(eventId) {
            selectedEvents.remove(eventId)
        } else {
            selectedEvents.insert(eventId)
        }
    }

    private func getSampleKeywords() -> String {
        return "any"
    }
}

struct EventSelectionRow: View {
    let event: CalendarEvent
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .purple : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !event.photoURLs.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text("\(event.photoURLs.count)")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct WidgetPreviewView: View {
    let widgetType: WidgetType?
    let events: [CalendarEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    Text(widgetType != nil ? "\(WidgetDataManager.shared.getWidgetTitle(for: widgetType!)) Configured!" : "Widgets Configured!")
                        .font(.title)
                        .fontWeight(.bold)

                    if let widgetType = widgetType {
                        Text("Your \(WidgetDataManager.shared.getWidgetTitle(for: widgetType).lowercased()) widget has been configured. Photos will cycle every 20 minutes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("All widget types have been configured with your events. Photos will cycle every 20 minutes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                // Widget Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to add the widget:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1.")
                                .fontWeight(.semibold)
                            Text("Long press on your home screen")
                        }

                        HStack {
                            Text("2.")
                                .fontWeight(.semibold)
                            Text("Tap the + button in the top left")
                        }

                        HStack {
                            Text("3.")
                                .fontWeight(.semibold)
                            Text("Search for \"Lovely\" and choose \"\(WidgetDataManager.shared.getWidgetTitle(for: widgetType!))\"")
                        }

                        HStack {
                            Text("4.")
                                .fontWeight(.semibold)
                            Text("Choose \"Small\" size and tap \"Add Widget\"")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                // Widget Types List
                if widgetType == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configured Widget Types:")
                            .font(.headline)

                        ForEach(WidgetType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(WidgetDataManager.shared.getWidgetTitle(for: type))
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if let widgetType = widgetType {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Widget Type:")
                            .font(.headline)

                        HStack {
                            Image(systemName: widgetType.icon)
                                .foregroundColor(widgetType.color)
                            Text(WidgetDataManager.shared.getWidgetTitle(for: widgetType))
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Widget Ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TitleEditorView: View {
    let currentTitle: String
    let widgetType: WidgetType
    let onSave: (String) -> Void

    @State private var editedTitle: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Widget Title")
                        .font(.headline)

                    TextField("Enter widget title", text: $editedTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }

                HStack {
                    Image(systemName: widgetType.icon)
                        .font(.title2)
                        .foregroundColor(widgetType.color)

                    Text(editedTitle.isEmpty ? "Widget Title" : editedTitle)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedTitle.isEmpty ? widgetType.defaultTitle : editedTitle)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editedTitle = currentTitle == widgetType.defaultTitle ? "" : currentTitle
        }
    }
}