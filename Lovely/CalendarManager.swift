import Foundation
import FirebaseFirestore
import UIKit

@MainActor
class CalendarManager: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let s3Manager = S3Manager.shared

    // MARK: - Event Management

    func loadEvents(for coupleId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let querySnapshot = try await db.collection("events")
                .whereField("coupleId", isEqualTo: coupleId)
                .getDocuments()

            let loadedEvents = try querySnapshot.documents.compactMap { document in
                var event = try document.data(as: CalendarEvent.self)
                event.id = document.documentID
                return event
            }

            // Sort events by date locally instead of in query
            events = loadedEvents.sorted { $0.date < $1.date }
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func addEvent(_ event: CalendarEvent, coupleId: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            var newEvent = event
            newEvent.coupleId = coupleId
            newEvent.createdAt = Date()

            let documentRef = try db.collection("events").addDocument(from: newEvent)
            newEvent.id = documentRef.documentID

            events.append(newEvent)
            events.sort { $0.date < $1.date }
        } catch {
            let errorMsg = "Failed to add event: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("CalendarManager Error: \(errorMsg)")

            // Log specific network errors
            if error.localizedDescription.contains("Network connectivity") {
                print("Network connectivity issue detected - event may be cached locally")
            }

            throw error
        }

        isLoading = false
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        guard let eventId = event.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            try db.collection("events").document(eventId).setData(from: event)

            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index] = event
                events.sort { $0.date < $1.date }
            }
        } catch {
            errorMessage = "Failed to update event: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func deleteEvent(_ event: CalendarEvent) async throws {
        guard let eventId = event.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Delete photos from S3 first
            await s3Manager.deletePhotos(keys: event.photoURLs)

            // Delete event document
            try await db.collection("events").document(eventId).delete()

            events.removeAll { $0.id == eventId }
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    // MARK: - Photo Management

    func uploadPhotos(_ images: [UIImage], for event: CalendarEvent) async throws -> [String] {
        guard let eventId = event.id else {
            throw NSError(domain: "CalendarManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Event ID is required"])
        }

        return try await s3Manager.uploadPhotos(images, eventId: eventId)
    }


    // MARK: - Caching

    private func cacheEvents() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: "cachedEvents")
        }
    }

    private func loadCachedEvents() -> [CalendarEvent]? {
        guard let data = UserDefaults.standard.data(forKey: "cachedEvents"),
              let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) else {
            return nil
        }
        return events
    }

    func loadEventsWithCache(for coupleId: String) async {
        // Load cached events first for instant display
        if let cached = loadCachedEvents() {
            events = cached
        }

        // Then refresh from server
        await loadEvents(for: coupleId)
        cacheEvents()
    }

    // MARK: - Comment Management

    func addComment(to event: CalendarEvent, comment: Comment) async throws {
        guard let eventId = event.id else {
            throw NSError(domain: "CalendarManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Event ID is required"])
        }

        // Check comment limit
        if event.comments.count >= 50 {
            throw NSError(domain: "CalendarManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Comment limit reached"])
        }

        isLoading = true
        errorMessage = nil

        do {
            // Convert comment to dictionary for Firestore
            let commentData: [String: Any] = [
                "id": comment.id,
                "userId": comment.userId,
                "userName": comment.userName,
                "text": comment.text,
                "createdAt": comment.createdAt
            ]

            // Add comment to Firestore using arrayUnion
            try await db.collection("events").document(eventId).updateData([
                "comments": FieldValue.arrayUnion([commentData])
            ])

            print("Successfully added comment to Firestore for event \(eventId)")

            // Update local event in the events array
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].comments.append(comment)
                print("Updated local events array with new comment")
            }
        } catch {
            print("Failed to add comment to Firestore: \(error)")
            errorMessage = "Failed to add comment: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func loadEventComments(eventId: String) async throws -> [Comment] {
        let document = try await db.collection("events").document(eventId).getDocument()

        if document.exists {
            let eventData = try document.data(as: CalendarEvent.self)
            return eventData.comments
        }

        return []
    }
}