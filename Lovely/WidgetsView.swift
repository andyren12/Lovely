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
                    Button("Preview") {
                        showingWidgetPreview = true
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
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Widget Preview")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This is how your widget will look with the selected events:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Mock widget preview
                    VStack(spacing: 12) {
                        ForEach(selectedEvents.prefix(4)) { event in
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.purple)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Text("Note: Widget functionality is coming soon! This preview shows how your selected events will be organized.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Preview")
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