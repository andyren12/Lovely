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

    func fileName(for userId: String) -> String {
        // Regular widgets are user-specific
        return "widget_photos_\(rawValue)_\(userId).json"
    }

    var fileName: String {
        // Fallback for legacy usage - will be replaced with user-specific version
        return "widget_photos_\(rawValue).json"
    }

}

struct WidgetsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedWidgetType: WidgetType?
    @State private var showingWidgetPreview = false
    @State private var showingWidgetEdit = false
    @State private var hasLoadedEvents = false
    @State private var refreshTrigger = 0

    // Computed property to ensure we only show sheet when widget type is available
    private var shouldShowEditSheet: Bool {
        showingWidgetEdit && selectedWidgetType != nil
    }

    private var shouldShowPreviewSheet: Bool {
        showingWidgetPreview && selectedWidgetType != nil
    }

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
        .sheet(isPresented: Binding<Bool>(
            get: { shouldShowEditSheet },
            set: { newValue in
                if !newValue {
                    showingWidgetEdit = false
                    selectedWidgetType = nil
                }
            }
        )) {
            WidgetEditView(
                widgetType: selectedWidgetType!,  // Force unwrap is safe due to shouldShowEditSheet check
                availableEvents: availableEvents,
                onComplete: {
                    showingWidgetEdit = false
                    selectedWidgetType = nil
                    refreshTrigger += 1  // Trigger refresh
                }
            )
        }
        .sheet(isPresented: Binding<Bool>(
            get: { shouldShowPreviewSheet },
            set: { newValue in
                if !newValue {
                    showingWidgetPreview = false
                    selectedWidgetType = nil
                }
            }
        )) {
            WidgetPreviewView(widgetType: selectedWidgetType!, events: availableEvents)  // Force unwrap is safe
        }
    }

    private var widgetTypesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Widgets")
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
                            availableEvents: availableEvents,
                            refreshTrigger: refreshTrigger
                        ) {
                            selectedWidgetType = widgetType
                            showingWidgetEdit = true
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

    private func configureAllWidgets() {
        WidgetDataManager.shared.updateAllWidgetTypes(with: availableEvents)
        showingWidgetPreview = true
    }
}

struct WidgetTypeCard: View {
    let widgetType: WidgetType
    let availableEvents: [CalendarEvent]
    let refreshTrigger: Int
    let onConfigure: () -> Void

    @State private var customTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Widget title
            HStack {
                Text(customTitle.isEmpty ? widgetType.defaultTitle : customTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Spacer()
            }

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
            loadTitle()
        }
        .onChange(of: refreshTrigger) { _, _ in
            loadTitle()
        }
    }

    @MainActor
    private func loadTitle() {
        let userId = UserSession.shared.userProfile?.userId ?? ""
        customTitle = WidgetDataManager.shared.getWidgetTitle(for: widgetType, userId: userId)
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
                // Load previously selected events from widget configuration
                loadSelectedEvents()
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

    private func loadSelectedEvents() {
        // Load the current widget configuration to get previously selected events
        Task { @MainActor in
            let userId = UserSession.shared.userProfile?.userId ?? ""
            let fileName = widgetType.fileName(for: userId)
            loadSelectedEventsWithFileName(fileName)
        }
    }

    private func loadSelectedEventsWithFileName(_ fileName: String) {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app"),
              let data = try? Data(contentsOf: sharedContainer.appendingPathComponent(fileName)),
              let configuration = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data) else {
            // No previous configuration, start with empty selection
            selectedEvents = []
            return
        }

        // Set selected events to match the previously configured event IDs
        selectedEvents = Set(configuration.selectedEventIds)
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

// MARK: - Comprehensive Widget Edit View

struct WidgetEditView: View {
    let widgetType: WidgetType
    let availableEvents: [CalendarEvent]
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSession = UserSession.shared

    // Widget configuration state
    @State private var customTitle: String = ""
    @State private var selectedEvents: Set<String> = []

    init(widgetType: WidgetType, availableEvents: [CalendarEvent], onComplete: @escaping () -> Void) {
        self.widgetType = widgetType
        self.availableEvents = availableEvents
        self.onComplete = onComplete
    }

    private var filteredEvents: [CalendarEvent] {
        availableEvents
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Widget Preview Section
                VStack(spacing: 16) {
                    Text("Widget Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    // Mock widget preview
                    VStack(spacing: 12) {
                        HStack {
                            Text(customTitle.isEmpty ? widgetType.defaultTitle : customTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        HStack {
                            Text("\(selectedEvents.count) event\(selectedEvents.count == 1 ? "" : "s") selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemGray5).opacity(0.3))

                // Configuration Form
                Form {
                    Section("Widget Settings") {
                        // Title editing
                        HStack {
                            Text("Title")
                            TextField(widgetType.defaultTitle, text: $customTitle)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section("Select Events") {
                        if filteredEvents.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.stack")
                                    .font(.title2)
                                    .foregroundColor(.secondary)

                                Text("No events with photos")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(filteredEvents) { event in
                                EventSelectionRow(
                                    event: event,
                                    isSelected: selectedEvents.contains(event.id ?? "")
                                ) {
                                    toggleEventSelection(event)
                                }
                            }
                        }
                    }

                    if !selectedEvents.isEmpty {
                        Section {
                            Button("Select All") {
                                selectedEvents = Set(filteredEvents.compactMap { $0.id })
                            }
                            .foregroundColor(widgetType.color)

                            Button("Deselect All") {
                                selectedEvents = []
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
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
                        saveWidgetConfiguration()
                    }
                    .disabled(selectedEvents.isEmpty)
                }
            }
        }
        .onAppear {
            loadCurrentConfiguration()
        }
    }

    private func loadCurrentConfiguration() {
        Task { @MainActor in
            let userId = UserSession.shared.userProfile?.userId ?? ""
            let fileName = widgetType.fileName(for: userId)
            loadConfigurationWithFileName(fileName)
        }
    }

    private func loadConfigurationWithFileName(_ fileName: String) {
        // Load existing widget title and icon
        let userId = userSession.userProfile?.userId ?? ""
        customTitle = WidgetDataManager.shared.getWidgetTitle(for: widgetType, userId: userId)
        if customTitle == widgetType.defaultTitle {
            customTitle = ""
        }


        // Load previously selected events
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.lovely.app"),
              let data = try? Data(contentsOf: sharedContainer.appendingPathComponent(fileName)),
              let configuration = try? JSONDecoder().decode(WidgetConfigurationData.self, from: data) else {
            selectedEvents = []
            return
        }

        selectedEvents = Set(configuration.selectedEventIds)
    }

    private func toggleEventSelection(_ event: CalendarEvent) {
        guard let eventId = event.id else { return }

        if selectedEvents.contains(eventId) {
            selectedEvents.remove(eventId)
        } else {
            selectedEvents.insert(eventId)
        }
    }

    private func saveWidgetConfiguration() {
        let eventsToUse = filteredEvents.filter { event in
            selectedEvents.contains(event.id ?? "")
        }

        let userId = userSession.userProfile?.userId ?? ""

        // Save title
        let finalTitle = customTitle.isEmpty ? widgetType.defaultTitle : customTitle
        WidgetDataManager.shared.setWidgetTitle(finalTitle, for: widgetType, userId: userId)


        // Save widget configuration
        WidgetDataManager.shared.updateWidgetConfiguration(selectedEvents: eventsToUse, for: widgetType, userId: userId)

        onComplete()
    }
}

