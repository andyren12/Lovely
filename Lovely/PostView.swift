import SwiftUI

struct PostView: View {
    @State var event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageCache = ImageCache.shared
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingImages = false
    @State private var currentImageIndex = 0
    @State private var newComment = ""
    @State private var isAddingComment = false

    private let maxComments = 50

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoadingImages {
                    loadingView
                } else if loadedImages.isEmpty {
                    noPhotosView
                } else {
                    photoCarouselView
                }

                ScrollView {
                    VStack(spacing: 0) {
                        postInfoView
                        commentsSection
                    }
                }

                commentInputView
            }
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboard()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadImages()
            loadComments()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Loading photos...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var noPhotosView: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("No photos in this event")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Add some memories to make this event special")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var photoCarouselView: some View {
        TabView(selection: $currentImageIndex) {
            ForEach(Array(loadedImages.enumerated()), id: \.offset) { index, image in
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .background(Color.black)
        .overlay(alignment: .topTrailing) {
            if loadedImages.count > 1 {
                photoCountIndicator
            }
        }
        .overlay(alignment: .bottom) {
            if loadedImages.count > 1 {
                pageIndicator
            }
        }
    }

    private var photoCountIndicator: some View {
        Text("\(currentImageIndex + 1) of \(loadedImages.count)")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            .padding(.top, 8)
            .padding(.trailing, 16)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<loadedImages.count, id: \.self) { index in
                Circle()
                    .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 16)
    }

    private var postInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(event.date.formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if !event.description.isEmpty {
                Text(event.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            }

            HStack {
                if !loadedImages.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(loadedImages.count) photo\(loadedImages.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !loadedImages.isEmpty && !event.comments.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !event.comments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(event.comments.count) comment\(event.comments.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !event.comments.isEmpty {
                Divider()
                    .padding(.horizontal)

                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(event.comments) { comment in
                        CommentRowView(comment: comment)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }

    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isAddingComment || event.comments.count >= maxComments)

                Button(action: addComment) {
                    if isAddingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Post")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         isAddingComment ||
                         event.comments.count >= maxComments)
                .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                               event.comments.count >= maxComments ? .secondary : .purple)
            }
            .padding()
            .background(Color(.systemBackground))

            if event.comments.count >= maxComments {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Comment limit reached (\(maxComments) max)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
            }
        }
    }

    private func loadImages() {
        guard !event.photoURLs.isEmpty else { return }

        Task {
            isLoadingImages = true
            var images: [UIImage] = []

            guard let eventId = event.id else {
                isLoadingImages = false
                return
            }

            for photoUrlOrKey in event.photoURLs {
                // Check cache first
                if let cachedImage = imageCache.getCachedEventPhoto(eventId: eventId, photoKey: photoUrlOrKey) {
                    images.append(cachedImage)
                    continue
                }

                do {
                    let finalURL: URL

                    // Check if this is already a full URL (legacy data) or a key (new format)
                    if photoUrlOrKey.hasPrefix("https://") {
                        // Legacy: This is a full URL, extract the key and generate signed URL
                        guard let key = S3Manager.shared.extractKeyFromURL(photoUrlOrKey) else {
                            print("Could not extract key from legacy URL: \(photoUrlOrKey)")
                            continue
                        }
                        finalURL = try await S3Manager.shared.getSignedURL(for: key)
                    } else {
                        // New format: This is an S3 key, generate signed URL
                        finalURL = try await S3Manager.shared.getSignedURL(for: photoUrlOrKey)
                    }

                    let (data, _) = try await URLSession.shared.data(from: finalURL)

                    if let image = UIImage(data: data) {
                        images.append(image)

                        // Cache the loaded image
                        imageCache.cacheEventPhoto(image, eventId: eventId, photoKey: photoUrlOrKey)
                    }
                } catch {
                    print("Failed to load photo from \(photoUrlOrKey): \(error)")
                }
            }

            await MainActor.run {
                loadedImages = images
                isLoadingImages = false
            }
        }
    }

    private func addComment() {
        guard let userProfile = userSession.userProfile,
              !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              event.comments.count < maxComments else { return }

        Task {
            isAddingComment = true

            let comment = Comment(
                userId: userProfile.userId,
                userName: userProfile.firstName,
                text: newComment.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            do {
                try await calendarManager.addComment(to: event, comment: comment)

                await MainActor.run {
                    event.comments.append(comment)
                    newComment = ""
                    isAddingComment = false
                }
            } catch {
                print("Failed to add comment: \(error)")
                isAddingComment = false
            }
        }
    }

    private func loadComments() {
        guard let eventId = event.id else { return }

        Task {
            do {
                let comments = try await calendarManager.loadEventComments(eventId: eventId)

                await MainActor.run {
                    event.comments = comments
                    print("Loaded \(comments.count) comments for event \(eventId)")
                }
            } catch {
                print("Failed to load comments: \(error)")
            }
        }
    }

}

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.userName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Text(timeAgoString(from: comment.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(comment.text)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
        }
        .padding(.vertical, 4)
    }

    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        // If less than 60 seconds ago, show "just now"
        if timeInterval < 60 {
            return "just now"
        }

        // Otherwise use the standard relative formatting
        return date.formatted(.relative(presentation: .numeric))
    }
}