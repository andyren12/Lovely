import SwiftUI

struct WidgetsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedEvents: Set<String> = []
    @State private var showingWidgetPreview = false

    var availableEvents: [CalendarEvent] {
        calendarManager.events.filter { !$0.photoURLs.isEmpty }
    }

    var body: some View {
        NavigationView {
            VStack {
                if userSession.isLoading || userManager.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !userSession.isInCouple {
                    noCoupleView
                } else if availableEvents.isEmpty {
                    noEventsView
                } else {
                    widgetCreationView
                }
            }
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Configure") {
                        configureWidget()
                    }
                    .disabled(selectedEvents.isEmpty)
                }
            }
            .onAppear {
                loadEvents()
            }
            .onChange(of: userSession.coupleId) {
                loadEvents()
            }
            .sheet(isPresented: $showingWidgetPreview) {
                WidgetPreviewView(selectedEventIds: Array(selectedEvents), events: availableEvents)
            }
        }
    }

    private var widgetCreationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Widget")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Select events to include in your widget. Choose photos and memories you want to display.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            List {
                ForEach(availableEvents) { event in
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

                    Button("Clear All") {
                        selectedEvents.removeAll()
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
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

            Text("Create some events with photos first, then come back here to make widgets")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadEvents() {
        guard let coupleId = userSession.coupleId else { return }

        Task {
            await calendarManager.loadEventsWithCache(for: coupleId)
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

    private func configureWidget() {
        let eventsToUse = availableEvents.filter { event in
            selectedEvents.contains(event.id ?? "")
        }

        WidgetDataManager.shared.updateWidgetConfiguration(selectedEvents: eventsToUse)

        // Show success feedback
        showingWidgetPreview = true
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
    let selectedEventIds: [String]
    let events: [CalendarEvent]
    @Environment(\.dismiss) private var dismiss

    private var selectedEvents: [CalendarEvent] {
        events.filter { event in
            selectedEventIds.contains(event.id ?? "")
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    Text("Widget Configured!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Your widget has been set up with \(selectedEvents.count) event\(selectedEvents.count == 1 ? "" : "s"). Photos will cycle every 20 minutes.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
                            Text("Search for \"Lovely\" and select the widget")
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

                // Selected Events List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Events:")
                        .font(.headline)

                    ForEach(selectedEvents.prefix(5)) { event in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.purple)
                            Text(event.title)
                                .font(.subheadline)
                            Spacer()
                        }
                    }

                    if selectedEvents.count > 5 {
                        Text("+ \(selectedEvents.count - 5) more events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

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