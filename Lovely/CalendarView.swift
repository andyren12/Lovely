import SwiftUI
import PhotosUI

struct CalendarView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var showingDatePicker = false
    @State private var selectedEvent: CalendarEvent?
    @State private var showingEventDetail = false
    @State private var eventToDelete: CalendarEvent?
    @State private var showingDeleteConfirmation = false

    var eventsForSelectedDate: [CalendarEvent] {
        calendarManager.events.filter { event in
            Calendar.current.isDate(event.date, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationView {
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
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(userSession.coupleId == nil)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(selectedDate: selectedDate) { event in
                Task {
                    if let coupleId = userSession.coupleId {
                        try? await calendarManager.addEvent(event, coupleId: coupleId)
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
            if deepLinkManager.shouldNavigateToEvent, let eventId = deepLinkManager.pendingEventId {
                navigateToEvent(eventId: eventId)
                deepLinkManager.clearPendingNavigation()
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
        // Find the event in the loaded events
        if let event = calendarManager.events.first(where: { $0.id == eventId }) {
            selectedEvent = event
            showingEventDetail = true
        } else {
            print("Event with ID \(eventId) not found in loaded events")
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()

    private var days: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            return []
        }

        let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)
        let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end)

        guard let firstWeek = monthFirstWeek, let lastWeek = monthLastWeek else {
            return []
        }

        var dates: [Date] = []
        var date = firstWeek.start

        while date <= lastWeek.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return dates
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        LazyVGrid(columns: columns, spacing: 8) {
            // Weekday headers
            ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            // Calendar days
            ForEach(days, id: \.self) { date in
                CalendarDayView(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                    hasEvents: hasEvents(for: date),
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                )
            }
        }
    }

    private func hasEvents(for date: Date) -> Bool {
        events.contains { event in
            calendar.isDate(event.date, inSameDayAs: date)
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let onTap: () -> Void

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.system(.subheadline, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : (isCurrentMonth ? .primary : .secondary))

                if hasEvents {
                    Circle()
                        .fill(isSelected ? Color.white : Color.blue)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 32, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    if !event.photoURLs.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.pink)
                            Text("\(event.photoURLs.count)")
                                .font(.caption)
                                .foregroundColor(.pink)
                        }
                    }
                }

                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                Text(event.isAllDay ? "All day" : event.date.formatted(date: .omitted, time: .shortened))
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

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()

                Spacer()
            }
            .navigationTitle("Select Date")
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

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date
    let onAdd: (CalendarEvent) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var isAllDay = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var eventPhotos: [UIImage] = []
    @State private var isUploading = false
    @State private var selectedBucketListItemId: String?
    @State private var selectedBucketListItem: BucketListItem?
    @State private var showingBucketListPicker = false
    @StateObject private var bucketListManager = BucketListManager()
    @StateObject private var smsManager = SMSManager.shared
    @State private var shouldTextPartner = false

    private let maxPhotos = 10

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event title", text: $title)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])

                    Toggle("All day", isOn: $isAllDay)
                }

                Section("Bucket List Item (Optional)") {
                    if let selectedItem = selectedBucketListItem {
                        HStack(spacing: 12) {
                            Image(systemName: selectedItem.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedItem.isCompleted ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedItem.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                if !selectedItem.description.isEmpty {
                                    Text(selectedItem.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Button("Change") {
                                showingBucketListPicker = true
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button(action: {
                            showingBucketListPicker = true
                        }) {
                            Label("Link Bucket List Item", systemImage: "list.clipboard")
                                .foregroundColor(.blue)
                        }
                    }
                }

                Section("Notifications") {
                    if SMSManager.shared.canSendText() {
                        Toggle("Text my partner about this event", isOn: $shouldTextPartner)
                    } else {
                        HStack {
                            Image(systemName: "message.slash")
                                .foregroundColor(.secondary)
                            Text("SMS not available on this device")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Photos (Optional)") {
                    if eventPhotos.isEmpty {
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: maxPhotos,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Add from Photos", systemImage: "plus")
                                    .foregroundColor(.blue)
                            }

                            Text("Add photos to capture memories for this event")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("\(eventPhotos.count)/\(maxPhotos) photos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if eventPhotos.count < maxPhotos {
                                    PhotosPicker(
                                        selection: $selectedItems,
                                        maxSelectionCount: maxPhotos - eventPhotos.count,
                                        matching: .images,
                                        photoLibrary: .shared()
                                    ) {
                                        Text("Add More")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(Array(eventPhotos.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)

                                        Button(action: {
                                            removePhoto(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isUploading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Add") {
                            Task {
                                await createEvent()
                            }
                        }
                        .disabled(!isFormValid)
                    }
                }
            }
        }
        .onAppear {
            // Set initial date to the selected date from calendar
            date = selectedDate
        }
        .onChange(of: selectedItems) {
            loadSelectedPhotos()
        }
        .sheet(isPresented: $showingBucketListPicker) {
            BucketListItemPicker(
                bucketListManager: bucketListManager,
                selectedBucketListItemId: $selectedBucketListItemId,
                onItemSelected: { item in
                    selectedBucketListItem = item
                    selectedBucketListItemId = item?.id
                }
            )
        }
        .sheet(isPresented: $smsManager.isShowingMessageComposer) {
            MessageComposeView(
                isShowing: $smsManager.isShowingMessageComposer,
                recipients: smsManager.messageRecipients,
                body: smsManager.messageBody
            )
        }
    }

    // MARK: - Photo Functions

    private func loadSelectedPhotos() {
        Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        eventPhotos.append(image)
                    }
                }
            }

            await MainActor.run {
                selectedItems = []
            }
        }
    }

    private func removePhoto(at index: Int) {
        eventPhotos.remove(at: index)
    }

    private func createEvent() async {
        isUploading = true

        do {
            // Create the event first
            var event = CalendarEvent(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                isAllDay: isAllDay,
                bucketListItemId: selectedBucketListItemId
            )

            // Upload photos if any
            if !eventPhotos.isEmpty {
                let eventId = UUID().uuidString
                let uploadedKeys = try await S3Manager.shared.uploadPhotos(eventPhotos, eventId: eventId)
                event.photoURLs = uploadedKeys

                // Cache the uploaded photos
                for (index, key) in uploadedKeys.enumerated() {
                    if index < eventPhotos.count {
                        ImageCache.shared.cacheEventPhoto(eventPhotos[index], eventId: eventId, photoKey: key)
                    }
                }

                print("Successfully uploaded \(uploadedKeys.count) photos for new event")
            }

            // Add the event
            onAdd(event)

            // Send SMS if enabled and partner phone number is available
            if shouldTextPartner,
               let currentUser = UserSession.shared.userProfile,
               let partnerProfile = UserSession.shared.partnerProfile,
               let partnerPhone = partnerProfile.phoneNumber,
               !partnerPhone.isEmpty {
                smsManager.sendEventNotification(
                    to: partnerPhone,
                    event: event,
                    senderName: currentUser.firstName
                )
            }

            dismiss()

        } catch {
            print("Failed to create event with photos: \(error)")
            // Could show an alert here
        }

        isUploading = false
    }
}

struct SwipeableEventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showingContextMenu = false

    private let maxDragDistance: CGFloat = 80
    private let deleteThreshold: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            // Event row
            EventRow(event: event)
                .offset(x: offset)
                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: offset)
                .onTapGesture {
                    if abs(offset) < 5 {
                        onTap()
                    } else {
                        // Close if open
                        offset = 0
                    }
                }
                .onLongPressGesture {
                    // Trigger haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showingContextMenu = true
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            // Only allow left swipe
                            if translation <= 0 {
                                offset = max(-maxDragDistance, translation)
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let velocity = value.predictedEndTranslation.width

                            // Determine final position based on translation and velocity
                            if translation < -deleteThreshold || velocity < -100 {
                                offset = -maxDragDistance
                            } else {
                                offset = 0
                            }
                        }
                )

            // Delete button
            if offset < 0 {
                Button(action: {
                    onDelete()
                    offset = 0
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Delete")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: -offset, height: 60)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("Delete Event", isPresented: $showingContextMenu) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(event.title)'?")
        }
    }
}
