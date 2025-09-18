import Foundation
import UIKit

@MainActor
class ImageCache: ObservableObject {
    static let shared = ImageCache()

    private var cache: [String: UIImage] = [:]
    private var lastAccessTime: [String: Date] = [:]
    private let maxCacheSize = 50 // Maximum number of images to cache
    private let cacheExpiryTime: TimeInterval = 60 * 60 // 1 hour

    private init() {
        // Clean up expired cache entries on init
        cleanupExpiredEntries()
    }

    // MARK: - Cache Operations

    func setImage(_ image: UIImage, forKey key: String) {
        // Clean up if cache is getting too large
        if cache.count >= maxCacheSize {
            removeOldestEntry()
        }

        cache[key] = image
        lastAccessTime[key] = Date()
        print("Cached image for key: \(key)")
    }

    func getImage(forKey key: String) -> UIImage? {
        // Check if entry exists and hasn't expired
        guard let image = cache[key],
              let accessTime = lastAccessTime[key],
              Date().timeIntervalSince(accessTime) < cacheExpiryTime else {
            // Remove expired entry
            removeImage(forKey: key)
            return nil
        }

        // Update access time
        lastAccessTime[key] = Date()
        print("Retrieved cached image for key: \(key)")
        return image
    }

    func removeImage(forKey key: String) {
        cache.removeValue(forKey: key)
        lastAccessTime.removeValue(forKey: key)
    }

    func clearCache() {
        cache.removeAll()
        lastAccessTime.removeAll()
        print("Cleared image cache")
    }

    // MARK: - Cache Management

    private func removeOldestEntry() {
        guard let oldestKey = lastAccessTime.min(by: { $0.value < $1.value })?.key else {
            return
        }

        removeImage(forKey: oldestKey)
        print("Removed oldest cache entry: \(oldestKey)")
    }

    private func cleanupExpiredEntries() {
        let now = Date()
        let expiredKeys = lastAccessTime.compactMap { key, accessTime in
            now.timeIntervalSince(accessTime) > cacheExpiryTime ? key : nil
        }

        for key in expiredKeys {
            removeImage(forKey: key)
        }

        if !expiredKeys.isEmpty {
            print("Cleaned up \(expiredKeys.count) expired cache entries")
        }
    }

    // MARK: - Cache Statistics

    var cacheStats: (count: Int, memoryUsage: String) {
        let count = cache.count
        let totalBytes = cache.values.reduce(0) { total, image in
            return total + (image.jpegData(compressionQuality: 1.0)?.count ?? 0)
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        let memoryUsage = formatter.string(fromByteCount: Int64(totalBytes))

        return (count: count, memoryUsage: memoryUsage)
    }

    func printCacheStats() {
        let stats = cacheStats
        print("Image Cache: \(stats.count) images, \(stats.memoryUsage)")
    }
}

// MARK: - Helper Extensions

extension ImageCache {

    // Generate cache key from event ID and photo key/URL
    static func cacheKey(eventId: String, photoKey: String) -> String {
        return "\(eventId)_\(photoKey.hashValue)"
    }

    // Convenience method for caching event photos
    func cacheEventPhoto(_ image: UIImage, eventId: String, photoKey: String) {
        let key = Self.cacheKey(eventId: eventId, photoKey: photoKey)
        setImage(image, forKey: key)
    }

    // Convenience method for retrieving event photos
    func getCachedEventPhoto(eventId: String, photoKey: String) -> UIImage? {
        let key = Self.cacheKey(eventId: eventId, photoKey: photoKey)
        return getImage(forKey: key)
    }

    // MARK: - Bucket List Item Cache Methods

    static func cacheKey(bucketListItemId: String, photoKey: String) -> String {
        return "bucket_\(bucketListItemId)_\(photoKey.hashValue)"
    }

    func cacheBucketListPhoto(_ image: UIImage, bucketListItemId: String, photoKey: String) {
        let key = Self.cacheKey(bucketListItemId: bucketListItemId, photoKey: photoKey)
        setImage(image, forKey: key)
    }

    func getCachedBucketListPhoto(bucketListItemId: String, photoKey: String) -> UIImage? {
        let key = Self.cacheKey(bucketListItemId: bucketListItemId, photoKey: photoKey)
        return getImage(forKey: key)
    }
}