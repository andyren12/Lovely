import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var imageCache = ImageCache.shared
    @State private var showingSettings = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var eventImages: [String: UIImage] = [:]
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if userSession.isInCouple {
                    eventsGridView
                } else {
                    noCoupleSection
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSettings) {
                SettingsView(authManager: authManager, userManager: userManager)
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var navigationTitle: String {
        return userSession.displayNamesHeader()
    }

    private var filteredEvents: [CalendarEvent] {
        let hideEventsWithoutPhotos = userSession.userSettings?.hideEventsWithoutPhotos ?? false

        if hideEventsWithoutPhotos {
            return calendarManager.events.filter { !$0.photoURLs.isEmpty }
        } else {
            return calendarManager.events
        }
    }

    private var eventsGridView: some View {
        ScrollView {
            VStack(spacing: 0) {
                coupleHeaderSection
                    .padding(.bottom, 16)

                if filteredEvents.isEmpty && !calendarManager.events.isEmpty {
                    // Show message when events are hidden due to filter
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.purple.opacity(0.6))

                        Text("No events with photos")
                            .font(.title3)
                            .fontWeight(.medium)

                        Text("Events without photos are hidden. Turn off this setting in Settings to see all events.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(filteredEvents) { event in
                            EventGridItem(event: event, eventImages: eventImages) {
                                selectedEvent = event
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadEvents()
        }
        .sheet(item: $selectedEvent) { event in
            if let eventIndex = filteredEvents.firstIndex(where: { $0.id == event.id }) {
                PostView(event: filteredEvents[eventIndex])
            } else {
                PostView(event: event)
            }
        }
    }

    private var coupleHeaderSection: some View {
        VStack(spacing: 16) {
            // Settings Button Row
            HStack {
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)

            // Profile Picture
            CoupleProfilePictureView(
                userManager: userManager
            )

            // Couple Names
            VStack(spacing: 4) {
                if let userFirstName = userSession.currentUserFirstName,
                   let partnerFirstName = userSession.partnerFirstName {
                    Text("\(userFirstName) + \(partnerFirstName)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Loading...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }

            // Relationship Duration and Dates Stat
            VStack(spacing: 8) {
                if let duration = userSession.relationshipDuration() {
                    VStack(spacing: 2) {
                        Text("Together for")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(duration)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                // Dates Stat
                if !filteredEvents.isEmpty {
                    VStack(spacing: 2) {
                        Text("\(filteredEvents.count)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Dates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }


    private func loadEvents() {
        guard let coupleId = userSession.couple?.id else { return }

        Task {
            await calendarManager.loadEvents(for: coupleId)
            await loadEventImages()
        }
    }

    private func loadEventImages() async {
        for event in filteredEvents {
            guard let eventId = event.id,
                  let firstPhotoKey = event.photoURLs.first,
                  eventImages[eventId] == nil else { continue }

            // Check cache first
            if let cachedImage = imageCache.getCachedEventPhoto(eventId: eventId, photoKey: firstPhotoKey) {
                await MainActor.run {
                    eventImages[eventId] = cachedImage
                }
                continue
            }

            // Load from S3
            do {
                let finalURL: URL

                // Check if this is already a full URL (legacy data) or a key (new format)
                if firstPhotoKey.hasPrefix("https://") {
                    // Legacy: This is a full URL, extract the key and generate signed URL
                    guard let key = S3Manager.shared.extractKeyFromURL(firstPhotoKey) else {
                        print("Could not extract key from legacy URL: \(firstPhotoKey)")
                        continue
                    }
                    finalURL = try await S3Manager.shared.getSignedURL(for: key)
                } else {
                    // New format: This is an S3 key, generate signed URL
                    finalURL = try await S3Manager.shared.getSignedURL(for: firstPhotoKey)
                }

                let (data, _) = try await URLSession.shared.data(from: finalURL)

                if let image = UIImage(data: data) {
                    // Cache the image
                    imageCache.cacheEventPhoto(image, eventId: eventId, photoKey: firstPhotoKey)

                    await MainActor.run {
                        eventImages[eventId] = image
                    }
                }
            } catch {
                print("Failed to load image for event \(eventId): \(error)")
            }
        }
    }

    private var noCoupleSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Partner Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create or join a couple to start sharing")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct EventGridItem: View {
    let event: CalendarEvent
    let eventImages: [String: UIImage]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let eventId = event.id,
                   let image = eventImages[eventId] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                        .clipped()
                } else if !event.photoURLs.isEmpty {
                    // Loading placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                } else {
                    // No photo placeholder
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.4), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundColor(.white)

                                Text(event.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(8)
                        )
                }

                // Photo count indicator for events with multiple photos
                if event.photoURLs.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "square.on.square")
                                .font(.caption)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CoupleProfilePictureView: View {
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var imageCache = ImageCache.shared
    @State private var profileImage: UIImage?
    @State private var showingActionSheet = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isUploading = false
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            ZStack {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 3)
                        )
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.4), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 3)
                        )
                }

                if isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 100, height: 100)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }

                // Edit indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                }
                .frame(width: 100, height: 100)
            }
        }
        .disabled(isUploading)
        .onAppear {
            loadProfilePicture()
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Profile Picture"),
                message: Text("Choose an option"),
                buttons: actionSheetButtons()
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            NavigationView {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)

                        Text("Choose Couple Photo")
                            .font(.headline)

                        Text("Select a photo that represents your relationship")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("Profile Picture")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingImagePicker = false
                        }
                    }
                }
            }
            .onChange(of: selectedItems) {
                handleSelectedImage()
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                Task {
                    await uploadProfilePicture(image)
                }
            }
        }
    }

    private func loadProfilePicture() {
        guard let couple = userSession.couple,
              let profilePictureURL = couple.profilePictureURL,
              let coupleId = couple.id else { return }

        // Check cache first
        let cacheKey = "couple_profile_\(coupleId)"
        if let cachedImage = imageCache.getImage(forKey: cacheKey) {
            profileImage = cachedImage
            return
        }

        Task {
            do {
                let finalURL: URL

                // Handle both S3 keys and full URLs
                if profilePictureURL.hasPrefix("https://") {
                    guard let key = S3Manager.shared.extractKeyFromURL(profilePictureURL) else {
                        print("Could not extract key from URL: \(profilePictureURL)")
                        return
                    }
                    finalURL = try await S3Manager.shared.getSignedURL(for: key)
                } else {
                    finalURL = try await S3Manager.shared.getSignedURL(for: profilePictureURL)
                }

                let (data, _) = try await URLSession.shared.data(from: finalURL)

                if let image = UIImage(data: data) {
                    await MainActor.run {
                        profileImage = image
                        imageCache.setImage(image, forKey: cacheKey)
                    }
                }
            } catch {
                print("Failed to load couple profile picture: \(error)")
            }
        }
    }

    private func handleSelectedImage() {
        guard let selectedItem = selectedItems.first else { return }

        Task {
            if let data = try? await selectedItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    showingImagePicker = false
                    selectedItems = []
                }

                await uploadProfilePicture(image)
            }
        }
    }

    private func uploadProfilePicture(_ image: UIImage) async {
        isUploading = true

        do {
            let uploadedKey = try await userManager.updateCoupleProfilePicture(image: image)

            await MainActor.run {
                profileImage = image

                // Cache the new image
                if let coupleId = userSession.couple?.id {
                    let cacheKey = "couple_profile_\(coupleId)"
                    imageCache.setImage(image, forKey: cacheKey)
                }

                isUploading = false
            }

            print("Successfully uploaded couple profile picture: \(uploadedKey)")
        } catch {
            await MainActor.run {
                isUploading = false
            }
            print("Failed to upload couple profile picture: \(error)")
        }
    }

    private func actionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []

        // Camera option
        buttons.append(.default(Text("Take Photo")) {
            showingCamera = true
        })

        // Photo library option
        buttons.append(.default(Text("Choose from Library")) {
            showingImagePicker = true
        })

        // Delete option (only if there's an existing photo)
        if profileImage != nil {
            buttons.append(.destructive(Text("Delete Photo")) {
                deleteProfilePicture()
            })
        }

        // Cancel option
        buttons.append(.cancel())

        return buttons
    }

    private func deleteProfilePicture() {
        guard userSession.couple?.hasProfilePicture == true else { return }

        Task {
            isUploading = true

            do {
                try await userManager.deleteCoupleProfilePicture()

                await MainActor.run {
                    profileImage = nil

                    // Remove from cache
                    if let coupleId = userSession.couple?.id {
                        let cacheKey = "couple_profile_\(coupleId)"
                        imageCache.removeImage(forKey: cacheKey)
                    }

                    isUploading = false
                }

                print("Successfully deleted couple profile picture")
            } catch {
                await MainActor.run {
                    isUploading = false
                }
                print("Failed to delete couple profile picture: \(error)")
            }
        }
    }
}
