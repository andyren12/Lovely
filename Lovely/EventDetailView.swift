import SwiftUI
import PhotosUI
import UIKit

struct EventDetailView: View {
    @Binding var event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var eventPhotos: [UIImage] = []
    @State private var newPhotos: [UIImage] = []
    @State private var isUploading = false
    @State private var isLoadingPhotos = false
    @State private var photosToDelete: Set<Int> = []
    @StateObject private var imageCache = ImageCache.shared
    @State private var isDismissing = false
    @State private var selectedBucketListItem: BucketListItem?
    @State private var showingBucketListPicker = false
    @StateObject private var bucketListManager = BucketListManager()

    private let maxPhotos = 10

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Event Info Section
                    eventInfoSection

                    // Photos Section
                    photosSection

                    Spacer(minLength: 120)
                }
                .padding()
            }
            .overlay(alignment: .bottom) {
                // Floating Camera Button
                if eventPhotos.count < maxPhotos {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                LinearGradient(
                                    colors: [.pink, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isDismissing = true
                        Task {
                            // Only upload new photos, don't delete marked photos
                            await uploadPendingPhotos()
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task {
                                await saveChanges()
                                await saveEvent()
                            }
                        } else {
                            // Clear deletion markers when starting to edit
                            photosToDelete.removeAll()
                        }
                        isEditing.toggle()
                    }
                    .disabled(isUploading)
                }
            }
        }
        .onAppear {
            loadPhotos()
            Task {
                if let bucketListId = UserSession.shared.bucketListId {
                    await bucketListManager.loadBucketList(for: bucketListId)
                    loadBucketListItem()
                }
            }
            print("EventDetailView appeared with event: \(event.title), date: \(event.date), description: '\(event.description)'")
        }
        .onDisappear {
            // Clear any remaining deletion markers without deleting
            photosToDelete.removeAll()
        }
    }

    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.pink)
                    .frame(width: 20)

                Text(event.date.formatted(date: .complete, time: event.isAllDay ? .omitted : .shortened))
                    .font(.subheadline)

                Spacer()
            }

            // Description
            if !event.description.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.pink)
                        .frame(width: 20)

                    if isEditing {
                        TextField("Description", text: Binding(
                            get: { event.description },
                            set: { event.description = $0 }
                        ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    } else {
                        Text(event.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // Bucket List Item
            if let bucketListItem = selectedBucketListItem {
                HStack(alignment: .top) {
                    Image(systemName: "list.clipboard")
                        .foregroundColor(.pink)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Linked to:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if isEditing {
                                Button("Change") {
                                    showingBucketListPicker = true
                                }
                                .font(.caption)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: bucketListItem.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundColor(bucketListItem.isCompleted ? .green : .secondary)

                            Text(bucketListItem.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        if !bucketListItem.description.isEmpty {
                            Text(bucketListItem.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
            } else if isEditing {
                HStack {
                    Image(systemName: "list.clipboard")
                        .foregroundColor(.pink)
                        .frame(width: 20)
                    Button("Link Bucket List Item") {
                        showingBucketListPicker = true
                    }
                    .font(.subheadline)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Photos")
                    .font(.headline)

                Spacer()
            }

            if isLoadingPhotos {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Loading photos...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if eventPhotos.isEmpty {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        Text("No photos yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Add memories to this event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)

                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: maxPhotos,
                        matching: .images
                    ) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text("Add from Photos")
                                .font(.caption)
                        }
                        .foregroundColor(.pink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
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
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .opacity(photosToDelete.contains(index) ? 0.5 : 1.0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(photosToDelete.contains(index) ? Color.red : Color.clear, lineWidth: 2)
                                )

                            if isEditing {
                                Button(action: {
                                    markPhotoForDeletion(at: index)
                                }) {
                                    Image(systemName: photosToDelete.contains(index) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(photosToDelete.contains(index) ? .green : .red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                    }

                    // Add photo button at the end of the grid
                    if eventPhotos.count < maxPhotos {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: maxPhotos - eventPhotos.count,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title)
                                    .foregroundColor(.pink)

                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundColor(.pink)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            HStack {
                Text("\(eventPhotos.count)/\(maxPhotos) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isUploading {
                    Spacer()
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Uploading...")
                            .font(.caption)
                            .foregroundColor(.pink)
                    }
                }
            }
        }
        .onChange(of: selectedItems) {
            loadSelectedPhotos()
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                // Failsafe: Check if adding this photo would exceed the limit
                if eventPhotos.count < maxPhotos {
                    eventPhotos.append(image)
                    newPhotos.append(image)
                } else {
                    print("Photo limit reached. Cannot add more photos from camera.")
                }
            }
        }
        .sheet(isPresented: $showingBucketListPicker) {
            BucketListItemPicker(
                bucketListManager: bucketListManager,
                selectedBucketListItemId: Binding(
                    get: { event.bucketListItemId },
                    set: { newId in
                        event.bucketListItemId = newId
                        loadBucketListItem()
                    }
                ),
                onItemSelected: { item in
                    selectedBucketListItem = item
                    event.bucketListItemId = item?.id
                }
            )
        }
    }

    private func loadPhotos() {
        // Load existing photos from S3 URLs
        guard !event.photoURLs.isEmpty else { return }

        Task {
            await loadPhotosFromURLs()
        }
    }

    private func loadPhotosFromURLs() async {
        isLoadingPhotos = true
        var loadedImages: [UIImage] = []

        guard let eventId = event.id else {
            isLoadingPhotos = false
            return
        }

        for photoUrlOrKey in event.photoURLs {
            // Check cache first
            if let cachedImage = imageCache.getCachedEventPhoto(eventId: eventId, photoKey: photoUrlOrKey) {
                loadedImages.append(cachedImage)
                print("Using cached image for \(photoUrlOrKey)")
                continue
            }

            do {
                print("Loading photo with URL/key: \(photoUrlOrKey)")

                let finalURL: URL

                // Check if this is already a full URL (legacy data) or a key (new format)
                if photoUrlOrKey.hasPrefix("https://") {
                    // Legacy: This is a full URL, extract the key and generate signed URL
                    guard let key = S3Manager.shared.extractKeyFromURL(photoUrlOrKey) else {
                        print("Could not extract key from legacy URL: \(photoUrlOrKey)")
                        continue
                    }
                    finalURL = try await S3Manager.shared.getSignedURL(for: key)
                    print("Extracted key '\(key)' from legacy URL and generated signed URL: \(finalURL)")
                } else {
                    // New format: This is an S3 key, generate signed URL
                    finalURL = try await S3Manager.shared.getSignedURL(for: photoUrlOrKey)
                    print("Generated signed URL from key: \(finalURL)")
                }

                let (data, response) = try await URLSession.shared.data(from: finalURL)

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode) for \(photoUrlOrKey)")
                }

                if let image = UIImage(data: data) {
                    loadedImages.append(image)

                    // Cache the loaded image
                    imageCache.cacheEventPhoto(image, eventId: eventId, photoKey: photoUrlOrKey)

                    print("Successfully loaded and cached image from \(photoUrlOrKey)")
                } else {
                    print("Failed to create image from data for \(photoUrlOrKey)")
                }
            } catch {
                print("Failed to load photo from \(photoUrlOrKey): \(error)")
            }
        }

        // Set existing photos (don't include in newPhotos since they're already uploaded)
        eventPhotos = loadedImages
        isLoadingPhotos = false
        print("Loaded \(loadedImages.count) existing photos from S3")

        // Print cache statistics
        imageCache.printCacheStats()
    }

    private func loadSelectedPhotos() {
        Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        // Failsafe: Check if adding this photo would exceed the limit
                        let currentTotal = eventPhotos.count
                        if currentTotal >= maxPhotos {
                            print("Photo limit reached. Cannot add more photos.")
                            return
                        }
                        eventPhotos.append(image)
                        newPhotos.append(image)
                    }
                }
            }

            await MainActor.run {
                selectedItems = []
            }
        }
    }

    private func markPhotoForDeletion(at index: Int) {
        if photosToDelete.contains(index) {
            photosToDelete.remove(index)
        } else {
            photosToDelete.insert(index)
        }
    }

    private func deleteMarkedPhotos() async {
        guard !photosToDelete.isEmpty else { return }

        // Sort indices in descending order to avoid index shifting issues
        let sortedIndices = photosToDelete.sorted(by: >)
        var deletedKeys: [String] = []

        // Collect photo keys to delete
        var photoKeysToDelete: [String] = []
        for index in sortedIndices {
            guard index < event.photoURLs.count else { continue }
            photoKeysToDelete.append(event.photoURLs[index])
        }

        // Delete photos from S3 directly
        for photoKey in photoKeysToDelete {
            do {
                // Determine the S3 key to delete
                let keyToDelete: String
                if photoKey.hasPrefix("https://") {
                    // Extract key from legacy URL
                    guard let key = S3Manager.shared.extractKeyFromURL(photoKey) else {
                        print("Could not extract key from URL: \(photoKey)")
                        continue
                    }
                    keyToDelete = key
                } else {
                    // It's already a key
                    keyToDelete = photoKey
                }

                // Delete from S3
                try await S3Manager.shared.deletePhoto(key: keyToDelete)
                print("Successfully deleted photo from S3 with key: \(keyToDelete)")

                deletedKeys.append(photoKey)

            } catch {
                print("Failed to delete photo from S3: \(error)")
                // Continue with other photos even if one fails
            }
        }

        // Update event and local arrays only for successfully deleted photos
        if !deletedKeys.isEmpty {
            let finalDeletedKeys = deletedKeys // Capture the final array
            await MainActor.run {
                var updatedEvent = event
                var updatedPhotos = eventPhotos

                // Remove successfully deleted photos from both arrays (in reverse order)
                for index in sortedIndices {
                    if index < updatedEvent.photoURLs.count && finalDeletedKeys.contains(updatedEvent.photoURLs[index]) {
                        let deletedPhotoKey = updatedEvent.photoURLs[index]

                        // Remove from cache
                        if let eventId = event.id {
                            imageCache.removeImage(forKey: ImageCache.cacheKey(eventId: eventId, photoKey: deletedPhotoKey))
                        }

                        updatedEvent.photoURLs.remove(at: index)
                        if index < updatedPhotos.count {
                            updatedPhotos.remove(at: index)
                        }
                    }
                }

                event = updatedEvent // This triggers the binding setter which saves to Firestore
                eventPhotos = updatedPhotos
                photosToDelete.removeAll()
            }
            print("Successfully updated event in Firestore after deleting \(finalDeletedKeys.count) photos")
        }
    }

    private func uploadPendingPhotos() async {
        guard !newPhotos.isEmpty else { return }

        isUploading = true

        do {
            // Failsafe: Check current photo count and only upload photos that keep total ≤ 10
            let currentPhotoCount = event.photoURLs.count
            let availableSlots = max(0, maxPhotos - currentPhotoCount)

            if availableSlots == 0 {
                print("Photo limit reached. Cannot upload any more photos.")
                newPhotos.removeAll()
                isUploading = false
                return
            }

            // Only upload photos that fit within the limit
            let photosToUpload = Array(newPhotos.prefix(availableSlots))
            if photosToUpload.count < newPhotos.count {
                print("Photo limit failsafe: Only uploading \(photosToUpload.count) of \(newPhotos.count) photos to stay within limit")
            }

            // Only upload new photos - don't delete on dismiss
            let uploadedKeys = try await S3Manager.shared.uploadPhotos(photosToUpload, eventId: event.id ?? UUID().uuidString)

            // Cache the newly uploaded photos
            if let eventId = event.id {
                for (index, key) in uploadedKeys.enumerated() {
                    if index < photosToUpload.count {
                        imageCache.cacheEventPhoto(photosToUpload[index], eventId: eventId, photoKey: key)
                    }
                }
            }

            // Add new keys to existing photoURLs (which now stores S3 keys)
            var updatedEvent = event
            updatedEvent.photoURLs.append(contentsOf: uploadedKeys)

            // Update the event binding (this will persist to Firestore via CalendarView)
            event = updatedEvent

            // Clear new photos since they're now uploaded
            newPhotos.removeAll()

            print("Successfully uploaded and cached \(uploadedKeys.count) photos to S3")
        } catch {
            print("Failed to upload photos: \(error)")
            // You might want to show an alert to the user here
        }

        isUploading = false
    }

    private func saveChanges() async {
        guard !newPhotos.isEmpty || !photosToDelete.isEmpty else { return }

        isUploading = true

        // First delete marked photos
        await deleteMarkedPhotos()

        // Then upload new photos if any
        await uploadPendingPhotos()

        isUploading = false
    }

    private func saveEvent() async {
        // The event binding automatically saves changes through CalendarView's binding setter
        // No need to manually call CalendarManager here since the binding handles it
        print("Event changes will be saved automatically through binding")
    }

    private func loadBucketListItem() {
        guard let bucketListItemId = event.bucketListItemId,
              let bucketList = bucketListManager.bucketList else {
            selectedBucketListItem = nil
            return
        }

        selectedBucketListItem = bucketList.items.first { $0.id == bucketListItemId }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraFlashMode = .auto
        picker.cameraCaptureMode = .photo

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        private var isFrontCamera = false

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            var capturedImage: UIImage?

            if let editedImage = info[.editedImage] as? UIImage {
                capturedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                capturedImage = originalImage
            }

            guard let image = capturedImage else {
                parent.dismiss()
                return
            }

            // Check which camera was used and apply fix if needed
            isFrontCamera = picker.cameraDevice == .front
            let fixedImage = isFrontCamera ? horizontallyFlipImage(image) : image

            parent.onImageCaptured(fixedImage)
            parent.dismiss()
        }

        private func horizontallyFlipImage(_ image: UIImage) -> UIImage {
            guard let cgImage = image.cgImage else { return image }

            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

            guard let context = CGContext(data: nil,
                                        width: width,
                                        height: height,
                                        bitsPerComponent: cgImage.bitsPerComponent,
                                        bytesPerRow: 0,
                                        space: colorSpace,
                                        bitmapInfo: cgImage.bitmapInfo.rawValue) else {
                return image
            }

            // Flip horizontally to correct front camera mirroring
            context.translateBy(x: CGFloat(width), y: 0)
            context.scaleBy(x: -1.0, y: 1.0)

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            guard let flippedCGImage = context.makeImage() else { return image }

            return UIImage(cgImage: flippedCGImage, scale: image.scale, orientation: .up)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
