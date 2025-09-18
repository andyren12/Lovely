import SwiftUI

struct CalendarBucketListView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedView: ViewType = .calendar
    @State private var showingAddEvent = false
    @State private var showingAddBucketItem = false
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var bucketListManager = BucketListManager()
    
    enum ViewType: String, CaseIterable {
        case calendar = "Calendar"
        case bucketList = "Bucket List"
        
        var iconName: String {
            switch self {
            case .calendar:
                return "calendar"
            case .bucketList:
                return "list.clipboard"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Dropdown Header with Plus Button
            HStack {
                // Left spacer for balance
                Spacer()
                
                // Centered dropdown menu
                Menu {
                    ForEach(ViewType.allCases, id: \.self) { viewType in
                        Button {
                            selectedView = viewType
                        } label: {
                            Label(viewType.rawValue, systemImage: viewType.iconName)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedView.iconName)
                        Text(selectedView.rawValue)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                }
                
                // Right spacer and plus button
                Spacer()
                
                if selectedView == .calendar || selectedView == .bucketList {
                    Button {
                        if selectedView == .calendar {
                            showingAddEvent = true
                        } else {
                            showingAddBucketItem = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Content View
            Group {
                switch selectedView {
                case .calendar:
                    CalendarContentView(authManager: authManager, userManager: userManager)
                        .environmentObject(deepLinkManager)
                case .bucketList:
                    BucketListContentView(authManager: authManager, userManager: userManager, bucketListManager: bucketListManager)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddEvent) {
            if selectedView == .calendar {
                AddEventView(selectedDate: Date(), calendarManager: calendarManager) { event in
                    Task {
                        if let coupleId = userSession.coupleId {
                            do {
                                try await calendarManager.addEvent(event, coupleId: coupleId)
                            } catch {
                                print("❌ Failed to add event: \(error)")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddBucketItem) {
            if selectedView == .bucketList {
                AddBucketItemView { title, description in
                    if let bucketListId = userSession.bucketListId {
                        Task {
                            do {
                                try await bucketListManager.addBucketItem(
                                    title: title,
                                    description: description,
                                    bucketListId: bucketListId
                                )
                            } catch {
                                print("❌ Failed to add bucket item: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
}

// Extract bucket list content without navigation wrapper
struct BucketListContentView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @ObservedObject var bucketListManager: BucketListManager
    @StateObject private var userSession = UserSession.shared
    @State private var showAlert = false
    @State private var selectedItem: BucketListItem?

    private var bucketListId: String? {
        userSession.bucketListId
    }

    private var isInCouple: Bool {
        userSession.isInCouple
    }

    private var incompleteItems: [BucketListItem] {
        bucketListManager.bucketItems.filter { !$0.isCompleted }
    }

    private var completedItems: [BucketListItem] {
        bucketListManager.bucketItems.filter { $0.isCompleted }
    }

    var body: some View {
        Group {
            if userSession.isLoading || userManager.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bucketListManager.isLoading && bucketListManager.bucketItems.isEmpty {
                ProgressView("Loading bucket list...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isInCouple && bucketListId != nil {
                bucketListContent
            } else {
                noCoupleView
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(bucketListManager.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            loadBucketListIfNeeded()
        }
        .onChange(of: userSession.bucketListId) {
            loadBucketListIfNeeded()
        }
        .onChange(of: bucketListManager.errorMessage) {
            showAlert = bucketListManager.errorMessage != nil
        }
        .sheet(item: $selectedItem) { item in
            BucketListItemDetailView(bucketListItem: .constant(item), bucketListManager: bucketListManager)
        }
    }

    private var bucketListContent: some View {
        List {
            if bucketListManager.bucketItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)

                    Text("Your Bucket List is Empty")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add dreams and goals you want to achieve together")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .listRowSeparator(.hidden)
            } else {
                // Incomplete Items Section
                if !incompleteItems.isEmpty {
                    Section("To Do") {
                        ForEach(incompleteItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                BucketListItemRow(
                                    item: item,
                                    onToggle: {
                                        completeItem(item)
                                    },
                                    onComplete: {
                                        completeItem(item)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { offsets in
                            if let bucketListId = bucketListId {
                                deleteIncompleteItems(offsets: offsets, bucketListId: bucketListId)
                            }
                        }
                    }
                }

                // Completed Items Section
                if !completedItems.isEmpty {
                    Section("Completed") {
                        ForEach(completedItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                BucketListItemRow(
                                    item: item,
                                    onToggle: {
                                        uncompleteItem(item)
                                    },
                                    onComplete: {
                                        toggleItemCompletion(item)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { offsets in
                            if let bucketListId = bucketListId {
                                deleteCompletedItems(offsets: offsets, bucketListId: bucketListId)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await refreshBucketList()
        }
        .listStyle(PlainListStyle())
    }

    private var noCoupleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Partner Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You need to create or join a couple to share a bucket list")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Private Methods (copied from BucketListView)
    private func loadBucketListIfNeeded() {
        guard let bucketListId = bucketListId else { return }

        Task {
            await bucketListManager.loadBucketList(for: bucketListId)
        }
    }

    private func completeItem(_ item: BucketListItem) {
        guard let bucketListId = userSession.bucketListId else { return }

        Task {
            do {
                var completedItem = item
                completedItem.isCompleted = true
                completedItem.completedAt = Date()

                try await bucketListManager.updateBucketListItem(bucketListId: bucketListId, item: completedItem)
            } catch {
                print("Failed to complete item: \(error)")
            }
        }
    }

    private func uncompleteItem(_ item: BucketListItem) {
        guard let bucketListId = userSession.bucketListId else { return }

        Task {
            do {
                var incompleteItem = item
                incompleteItem.isCompleted = false
                incompleteItem.completedAt = nil

                try await bucketListManager.updateBucketListItem(bucketListId: bucketListId, item: incompleteItem)
            } catch {
                print("Failed to uncomplete item: \(error)")
            }
        }
    }

    private func toggleItemCompletion(_ item: BucketListItem) {
        Task {
            do {
                try await bucketListManager.toggleItemCompletion(item)
            } catch {
                // Error is handled in BucketListManager
            }
        }
    }

    private func deleteIncompleteItems(offsets: IndexSet, bucketListId: String) {
        let itemsToDelete = Array(offsets).compactMap { index in
            index < incompleteItems.count ? incompleteItems[index] : nil
        }

        let fullListOffsets = IndexSet(itemsToDelete.compactMap { item in
            bucketListManager.bucketItems.firstIndex(where: { $0.id == item.id })
        })

        bucketListManager.deleteBucketItems(at: fullListOffsets, bucketListId: bucketListId)
    }

    private func deleteCompletedItems(offsets: IndexSet, bucketListId: String) {
        let itemsToDelete = Array(offsets).compactMap { index in
            index < completedItems.count ? completedItems[index] : nil
        }

        let fullListOffsets = IndexSet(itemsToDelete.compactMap { item in
            bucketListManager.bucketItems.firstIndex(where: { $0.id == item.id })
        })

        bucketListManager.deleteBucketItems(at: fullListOffsets, bucketListId: bucketListId)
    }

    private func refreshBucketList() async {
        guard let bucketListId = bucketListId else { return }
        await bucketListManager.refreshBucketList(for: bucketListId)
    }
}


// Extract the calendar content without the navigation wrapper
struct CalendarContentView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var showingDatePicker = false
    @State private var selectedEvent: CalendarEvent?
    @State private var eventToDelete: CalendarEvent?
    @State private var showingDeleteConfirmation = false

    var eventsForSelectedDate: [CalendarEvent] {
        calendarManager.events.filter { event in
            Calendar.current.isDate(event.date, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mini Calendar Header
            VStack(spacing: 16) {
                HStack {
                    Button {
                        showingDatePicker = true
                    } label: {
                        HStack {
                            Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                                .font(.title2)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }

                    Spacer()

                    HStack {
                        Button {
                            withAnimation {
                                selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            withAnimation {
                                selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }

                // Mini Calendar Grid
                CalendarGridView(selectedDate: $selectedDate, events: calendarManager.events)
            }
            .padding()
            .background(Color(.systemGray6))

            // Selected Date Events
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
                .padding(.horizontal)

                if eventsForSelectedDate.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No events for this day")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Tap + to add your first event")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(eventsForSelectedDate.sorted { $0.date < $1.date }) { event in
                                SwipeableEventRow(
                                    event: event,
                                    onTap: {
                                        selectedEvent = event
                                    },
                                    onDelete: {
                                        eventToDelete = event
                                        showingDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(selectedDate: selectedDate, calendarManager: calendarManager) { event in
                Task {
                    if let coupleId = userSession.coupleId {
                        do {
                            try await calendarManager.addEvent(event, coupleId: coupleId)
                        } catch {
                            print("❌ Failed to add event: \(error)")
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: Binding(
                get: {
                    // Find the current version of the event from the manager
                    calendarManager.events.first { $0.id == event.id } ?? event
                },
                set: { updatedEvent in
                    // Update the selected event locally
                    selectedEvent = updatedEvent

                    // Update in CalendarManager
                    Task {
                        try? await calendarManager.updateEvent(updatedEvent)
                    }
                }
            ))
        }
        .onAppear {
            loadEvents()
        }
        .onChange(of: userSession.coupleId) {
            loadEvents()
        }
        .onChange(of: deepLinkManager.shouldNavigateToEvent) {
            print("🔗 Deep Link - shouldNavigateToEvent changed to: \(deepLinkManager.shouldNavigateToEvent)")
            if deepLinkManager.shouldNavigateToEvent, let eventId = deepLinkManager.pendingEventId {
                print("🔗 Deep Link - Attempting to navigate to event: '\(eventId)'")
                navigateToEvent(eventId: eventId)
                deepLinkManager.clearPendingNavigation()
            } else if deepLinkManager.shouldNavigateToEvent {
                print("❌ Deep Link - shouldNavigateToEvent is true but no pendingEventId")
            }
        }
        .confirmationDialog(
            "Delete Event",
            isPresented: $showingDeleteConfirmation,
            presenting: eventToDelete
        ) { event in
            Button("Delete", role: .destructive) {
                deleteEvent(event)
            }
            Button("Cancel", role: .cancel) { }
        } message: { event in
            Text("Are you sure you want to delete '\(event.title)'? This will also delete all photos associated with this event.")
        }
        .overlay(
            // SMS clipboard notification
            Group {
                if SMSManager.shared.showClipboardNotification {
                    VStack {
                        Spacer()

                        HStack {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.white)
                            Text("Message copied to clipboard")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .padding(.bottom, 50)
                    .animation(.easeInOut(duration: 0.3), value: SMSManager.shared.showClipboardNotification)
                }
            }
        )
    }

    private func loadEvents() {
        guard let coupleId = userSession.coupleId else { return }

        Task {
            await calendarManager.loadEventsWithCache(for: coupleId)
        }
    }

    private func deleteEvent(_ event: CalendarEvent) {
        Task {
            do {
                // Delete from CalendarManager (which handles S3 photo deletion and Firestore)
                try await calendarManager.deleteEvent(event)

                // Also remove from image cache
                if let eventId = event.id {
                    for photoKey in event.photoURLs {
                        let cacheKey = ImageCache.cacheKey(eventId: eventId, photoKey: photoKey)
                        ImageCache.shared.removeImage(forKey: cacheKey)
                    }
                }

                print("Successfully deleted event '\(event.title)' and all associated photos")
            } catch {
                print("Failed to delete event: \(error)")
                // Could show an alert to the user here
            }
        }
    }

    private func navigateToEvent(eventId: String) {
        print("🔗 Deep Link - Looking for event '\(eventId)' in \(calendarManager.events.count) loaded events")

        // Find the event in the loaded events
        if let event = calendarManager.events.first(where: { $0.id == eventId }) {
            print("✅ Deep Link - Found event: '\(event.title)' with ID: '\(event.id ?? "nil")'")

            // Add delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.selectedEvent = event
                print("🔗 Deep Link - Set selectedEvent, should trigger sheet")
            }
        } else {
            print("❌ Deep Link - Event with ID '\(eventId)' not found in loaded events")
            print("🔗 Deep Link - Available event IDs: \(calendarManager.events.compactMap { $0.id })")

            // Try to load events and then navigate
            print("🔗 Deep Link - Attempting to load events first...")
            Task {
                if let coupleId = userSession.coupleId {
                    await calendarManager.loadEventsWithCache(for: coupleId)

                    // Try again after loading
                    await MainActor.run {
                        if let event = calendarManager.events.first(where: { $0.id == eventId }) {
                            print("✅ Deep Link - Found event after reload: '\(event.title)' with ID: '\(event.id ?? "nil")'")

                            // Add delay to ensure UI is ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.selectedEvent = event
                                print("🔗 Deep Link - Set selectedEvent after reload, should trigger sheet")
                            }
                        } else {
                            print("❌ Deep Link - Event still not found after reload")
                            print("🔗 Deep Link - Final available event IDs: \(calendarManager.events.compactMap { $0.id })")
                        }
                    }
                } else {
                    print("❌ Deep Link - No couple ID available")
                }
            }
        }
    }
}
