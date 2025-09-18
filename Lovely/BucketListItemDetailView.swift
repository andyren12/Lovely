import SwiftUI
import PhotosUI
import UIKit

struct BucketListItemDetailView: View {
    @Binding var bucketListItem: BucketListItem
    @Environment(\.dismiss) private var dismiss
    @State private var localItem: BucketListItem
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var itemPhotos: [UIImage] = []
    @State private var newPhotos: [UIImage] = []
    @State private var isUploading = false
    @State private var isLoadingPhotos = false
    @State private var photosToDelete: Set<Int> = []
    @StateObject private var imageCache = ImageCache.shared
    @State private var isDismissing = false
    @State private var showingUncompleteConfirmation = false
    @ObservedObject var bucketListManager: BucketListManager
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()

    private let maxPhotos = 10

    init(bucketListItem: Binding<BucketListItem>, bucketListManager: BucketListManager) {
        self._bucketListItem = bucketListItem
        self._localItem = State(initialValue: bucketListItem.wrappedValue)
        self.bucketListManager = bucketListManager
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Item Info Section
                    itemInfoSection

                    // Photos Section
                    photosSection

                    Spacer(minLength: 120)
                }
                .padding()
            }
            .overlay(alignment: .bottom) {
                // Floating Camera Button
                if itemPhotos.count < maxPhotos {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [.purple, .purple.opacity(0.6)]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(localItem.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !localItem.isCompleted {
                            Button {
                                completeItem()
                            } label: {
                                Label("Mark as Completed", systemImage: "checkmark.circle")
                            }
                        } else {
                            Button {
                                showingUncompleteConfirmation = true
                            } label: {
                                Label("Mark as Incomplete", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                print("onAppear: Loading photos. Current localItem.photoURLs count: \(localItem.photoURLs.count)")
                loadPhotos()
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedItems,
                maxSelectionCount: maxPhotos - itemPhotos.count,
                matching: .images,
                photoLibrary: .shared()
            )
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    if itemPhotos.count < maxPhotos {
                        print("Camera: Adding photo to newPhotos. Current newPhotos count: \(newPhotos.count)")
                        newPhotos.append(image)
                        print("Camera: About to call uploadNewPhotos()")
                        uploadNewPhotos()
                    }
                }
            }
            .onChange(of: selectedItems) {
                print("onChange: selectedItems changed to \(selectedItems.count) items")
                if !selectedItems.isEmpty {
                    loadSelectedPhotos()
                } else {
                    print("onChange: Ignoring empty selectedItems change")
                }
            }
            .alert("Mark as Incomplete?", isPresented: $showingUncompleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Mark Incomplete", role: .destructive) {
                    uncompleteItem()
                }
            } message: {
                Text("This will mark the item as incomplete and delete the post from your profile.")
            }
        }
    }

    // MARK: - Item Info Section
    private var itemInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: localItem.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(localItem.isCompleted ? .green : .secondary)
                        Text(localItem.isCompleted ? "Completed" : "In Progress")
                            .font(.subheadline)
                            .foregroundColor(localItem.isCompleted ? .green : .secondary)
                    }
                }

                if localItem.isCompleted, let completedAt = localItem.completedAt {
                    Text("Completed on \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !localItem.description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(localItem.description)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Created")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(localItem.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Photos Section
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Photos")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(itemPhotos.count)/\(maxPhotos)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isLoadingPhotos {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if itemPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No photos yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Add photos to capture memories of completing this bucket list item")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showingImagePicker = true
                    } label: {
                        Text("Add Photos")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Array(itemPhotos.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(photosToDelete.contains(index) ? Color.red : Color.clear, lineWidth: 2)
                                )

                            Button {
                                if photosToDelete.contains(index) {
                                    photosToDelete.remove(index)
                                } else {
                                    photosToDelete.insert(index)
                                }
                            } label: {
                                Image(systemName: photosToDelete.contains(index) ? "checkmark.circle.fill" : "minus.circle.fill")
                                    .foregroundColor(photosToDelete.contains(index) ? .green : .red)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }

                if itemPhotos.count < maxPhotos {
                    HStack {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: maxPhotos - itemPhotos.count,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Add More")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }

                        if !photosToDelete.isEmpty {
                            Button {
                                deleteSelectedPhotos()
                            } label: {
                                Text("Delete Selected (\(photosToDelete.count))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Photo Functions
    private func loadSelectedPhotos() {
        print("PhotoPicker: Starting to load \(selectedItems.count) selected photos")
        Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        print("PhotoPicker: Adding photo to newPhotos. Current newPhotos count: \(newPhotos.count)")
                        newPhotos.append(image)
                    }
                }
            }

            await MainActor.run {
                selectedItems = []
                print("PhotoPicker: About to call uploadNewPhotos() with \(newPhotos.count) photos")
                uploadNewPhotos()
            }
        }
    }

    private func uploadNewPhotos() {
        guard !newPhotos.isEmpty else {
            print("uploadNewPhotos: No new photos to upload")
            return
        }

        print("uploadNewPhotos: Starting upload of \(newPhotos.count) photos")
        print("uploadNewPhotos: Current photoURLs count: \(localItem.photoURLs.count)")

        // Capture the photos to upload and clear newPhotos immediately
        let photosToUpload = newPhotos
        newPhotos.removeAll()

        Task {
            do {
                isUploading = true
                let uploadedKeys = try await S3Manager.shared.uploadPhotos(photosToUpload, bucketListItemId: localItem.id)

                await MainActor.run {
                    print("uploadNewPhotos: Successfully uploaded \(uploadedKeys.count) photos")
                    print("uploadNewPhotos: Before append - photoURLs count: \(localItem.photoURLs.count)")

                    // Update the bucket list item
                    localItem.photoURLs.append(contentsOf: uploadedKeys)

                    print("uploadNewPhotos: After append - photoURLs count: \(localItem.photoURLs.count)")

                    // Add photos to display immediately (no loading time)
                    itemPhotos.append(contentsOf: photosToUpload)

                    // Cache the uploaded photos
                    for (index, key) in uploadedKeys.enumerated() {
                        if index < photosToUpload.count {
                            ImageCache.shared.cacheBucketListPhoto(photosToUpload[index], bucketListItemId: localItem.id, photoKey: key)
                        }
                    }

                    isUploading = false

                    // Update in Firestore
                    updateItemInFirestore()

                    // No need to reload photos - we already added them to itemPhotos
                }
            } catch {
                await MainActor.run {
                    print("Failed to upload photos: \(error)")
                    // Photos were already removed from newPhotos, no need to clear again
                    isUploading = false
                }
            }
        }
    }

    private func deleteSelectedPhotos() {
        Task {
            let keysToDelete = photosToDelete.compactMap { index in
                index < localItem.photoURLs.count ? localItem.photoURLs[index] : nil
            }

            // Delete from S3
            await S3Manager.shared.deletePhotos(keys: keysToDelete)

            await MainActor.run {
                // Remove from localItem.photoURLs (in reverse order to maintain indices)
                for index in photosToDelete.sorted(by: >) {
                    if index < localItem.photoURLs.count {
                        localItem.photoURLs.remove(at: index)
                    }
                }

                photosToDelete.removeAll()

                // Update in Firestore first
                updateItemInFirestore()

                // Reload photos to reflect changes (this will update itemPhotos)
                loadPhotos()
            }
        }
    }

    private func loadPhotos() {
        guard !localItem.photoURLs.isEmpty else {
            itemPhotos = []
            isLoadingPhotos = false
            return
        }

        isLoadingPhotos = true

        Task {
            var loadedImages: [UIImage] = []

            for photoKey in localItem.photoURLs {
                let cacheKey = ImageCache.cacheKey(bucketListItemId: localItem.id, photoKey: photoKey)

                if let cachedImage = ImageCache.shared.getImage(forKey: cacheKey) {
                    loadedImages.append(cachedImage)
                } else if let downloadedImage = await S3Manager.shared.downloadImage(key: photoKey) {
                    ImageCache.shared.cacheBucketListPhoto(downloadedImage, bucketListItemId: localItem.id, photoKey: photoKey)
                    loadedImages.append(downloadedImage)
                }
            }

            await MainActor.run {
                itemPhotos = loadedImages
                isLoadingPhotos = false
            }
        }
    }

    private func completeItem() {
        localItem.isCompleted = true
        localItem.completedAt = Date()
        updateItemInFirestore()

        Task {
            await createCalendarEvent()
        }
    }

    private func uncompleteItem() {
        localItem.isCompleted = false
        localItem.completedAt = nil
        updateItemInFirestore()

        Task {
            await removeCalendarEventIfExists()
        }
    }

    private func updateItemInFirestore() {
        guard let bucketListId = userSession.bucketListId else { return }

        Task {
            do {
                try await bucketListManager.updateBucketListItem(bucketListId: bucketListId, item: localItem)
                bucketListItem = localItem
            } catch {
                print("Failed to update bucket list item: \(error)")
            }
        }
    }

    private func createCalendarEvent() async {
        guard let coupleId = userSession.coupleId else {
            print("No couple ID available for creating calendar event")
            return
        }

        do {
            try await calendarManager.createEventFromBucketListItem(localItem, coupleId: coupleId)
            print("Successfully created calendar event for bucket list item: \(localItem.title)")
        } catch {
            print("Failed to create calendar event: \(error)")
        }
    }

    private func removeCalendarEventIfExists() async {
        guard let coupleId = userSession.coupleId else {
            print("No couple ID available for removing calendar event")
            return
        }

        do {
            try await calendarManager.deleteEventForBucketListItem(localItem.id, coupleId: coupleId)
            print("Successfully removed calendar event for bucket list item: \(localItem.title)")
        } catch {
            print("Failed to remove calendar event: \(error)")
        }
    }
}

