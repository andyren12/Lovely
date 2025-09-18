import Foundation
import FirebaseFirestore

@MainActor
class BucketListManager: ObservableObject {
    @Published var bucketList: BucketList?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let s3Manager = S3Manager.shared

    var bucketItems: [BucketListItem] {
        bucketList?.items ?? []
    }

    // MARK: - Caching

    private func cacheBucketList(_ bucketList: BucketList) {
        if let data = try? JSONEncoder().encode(bucketList),
           let bucketListId = bucketList.id {
            UserDefaults.standard.set(data, forKey: "cachedBucketList_\(bucketListId)")
        }
    }

    private func loadCachedBucketList(for bucketListId: String) -> BucketList? {
        guard let data = UserDefaults.standard.data(forKey: "cachedBucketList_\(bucketListId)"),
              let bucketList = try? JSONDecoder().decode(BucketList.self, from: data) else {
            return nil
        }
        return bucketList
    }

    // MARK: - Public Methods

    func loadBucketList(for bucketListId: String) async {
        // Load cached data first for instant display
        if let cached = loadCachedBucketList(for: bucketListId) {
            bucketList = cached
        }

        // Then refresh from server
        await refreshBucketList(for: bucketListId)
    }

    func addBucketItem(title: String, description: String, bucketListId: String) async throws {
        guard let bucketList = bucketList else { return }

        isLoading = true
        errorMessage = nil

        do {
            let newItem = BucketListItem(
                title: title,
                description: description,
                isCompleted: false,
                createdAt: Date(),
                completedAt: nil
            )

            var updatedItems = bucketList.items
            updatedItems.append(newItem)

            let updatedBucketList = BucketList(
                coupleId: bucketList.coupleId
            )

            var mutableBucketList = updatedBucketList
            mutableBucketList.id = bucketList.id
            mutableBucketList.items = updatedItems
            mutableBucketList.updatedAt = Date()

            try db.collection("bucketLists").document(bucketListId).setData(from: mutableBucketList)
            self.bucketList = mutableBucketList
            cacheBucketList(mutableBucketList)
        } catch {
            errorMessage = "Failed to add bucket item: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func toggleItemCompletion(_ item: BucketListItem) async throws {
        guard let bucketList = bucketList,
              let bucketListId = bucketList.id,
              let itemIndex = bucketList.items.firstIndex(where: { $0.id == item.id }) else { return }

        isLoading = true
        errorMessage = nil

        do {
            var updatedItems = bucketList.items
            updatedItems[itemIndex].isCompleted.toggle()
            updatedItems[itemIndex].completedAt = updatedItems[itemIndex].isCompleted ? Date() : nil

            var updatedBucketList = bucketList
            updatedBucketList.items = updatedItems
            updatedBucketList.updatedAt = Date()

            try db.collection("bucketLists").document(bucketListId).setData(from: updatedBucketList)
            self.bucketList = updatedBucketList
            cacheBucketList(updatedBucketList)
        } catch {
            errorMessage = "Failed to update item: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func deleteBucketItem(_ item: BucketListItem) async throws {
        guard let bucketList = bucketList,
              let bucketListId = bucketList.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Delete photos from S3 first
            if !item.photoURLs.isEmpty {
                await s3Manager.deletePhotos(keys: item.photoURLs)
                print("Deleted \(item.photoURLs.count) photos from S3 for bucket list item: \(item.title)")
            }

            var updatedItems = bucketList.items
            updatedItems.removeAll { $0.id == item.id }

            var updatedBucketList = bucketList
            updatedBucketList.items = updatedItems
            updatedBucketList.updatedAt = Date()

            try db.collection("bucketLists").document(bucketListId).setData(from: updatedBucketList)
            self.bucketList = updatedBucketList
            cacheBucketList(updatedBucketList)
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func refreshBucketList(for bucketListId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let document = try await db.collection("bucketLists").document(bucketListId).getDocument()

            if document.exists {
                let loadedBucketList = try document.data(as: BucketList.self)
                bucketList = loadedBucketList
                cacheBucketList(loadedBucketList)
            } else {
                bucketList = nil
            }
        } catch {
            errorMessage = "Failed to refresh bucket list: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func updateBucketListItem(bucketListId: String, item: BucketListItem) async throws {
        guard let bucketList = bucketList,
              let itemIndex = bucketList.items.firstIndex(where: { $0.id == item.id }) else {
            throw NSError(domain: "BucketListManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }

        isLoading = true
        errorMessage = nil

        do {
            var updatedBucketList = bucketList
            updatedBucketList.items[itemIndex] = item
            updatedBucketList.updatedAt = Date()

            try db.collection("bucketLists").document(bucketListId).setData(from: updatedBucketList)
            self.bucketList = updatedBucketList
            cacheBucketList(updatedBucketList)
        } catch {
            errorMessage = "Failed to update bucket list item: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func updateBucketListItemDirect(bucketListId: String, item: BucketListItem) async throws {
        // Load the bucket list first to ensure we have the latest data
        let document = try await db.collection("bucketLists").document(bucketListId).getDocument()

        guard document.exists,
              var bucketList = try? document.data(as: BucketList.self) else {
            throw NSError(domain: "BucketListManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bucket list not found"])
        }

        // Find and update the item
        guard let itemIndex = bucketList.items.firstIndex(where: { $0.id == item.id }) else {
            throw NSError(domain: "BucketListManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found in bucket list"])
        }

        // Update the item and save back to Firestore
        bucketList.items[itemIndex] = item
        bucketList.updatedAt = Date()

        try db.collection("bucketLists").document(bucketListId).setData(from: bucketList)

        print("Successfully updated bucket list item: \(item.title)")
    }

}

// MARK: - Extensions for Array Operations

extension BucketListManager {
    func deleteBucketItems(at offsets: IndexSet, bucketListId: String) {
        guard let bucketList = bucketList else { return }

        Task {
            isLoading = true
            errorMessage = nil

            do {
                // Get items to delete based on current bucket list state
                let itemsToDelete = offsets.compactMap { index in
                    index < bucketList.items.count ? bucketList.items[index] : nil
                }

                // Delete photos from S3 for all items being deleted
                for item in itemsToDelete {
                    if !item.photoURLs.isEmpty {
                        await s3Manager.deletePhotos(keys: item.photoURLs)
                        print("Deleted \(item.photoURLs.count) photos from S3 for bucket list item: \(item.title)")
                    }
                }

                // Remove all selected items at once
                var updatedItems = bucketList.items
                for item in itemsToDelete {
                    updatedItems.removeAll { $0.id == item.id }
                }

                var updatedBucketList = bucketList
                updatedBucketList.items = updatedItems
                updatedBucketList.updatedAt = Date()

                try db.collection("bucketLists").document(bucketListId).setData(from: updatedBucketList)
                self.bucketList = updatedBucketList
                cacheBucketList(updatedBucketList)
            } catch {
                errorMessage = "Failed to delete items: \(error.localizedDescription)"
            }

            isLoading = false
        }
    }
}