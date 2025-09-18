import Foundation
import UIKit
import AWSS3

@MainActor
class S3Manager: ObservableObject {
    static let shared = S3Manager()

    private let bucketName = "lovelyapp" // Replace with your bucket name
    private let region = AWSRegionType.USEast1 // Replace with your region

    private init() {
        configureAWS()
    }

    private func configureAWS() {
        // Configure AWS credentials
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: region,
            identityPoolId: "us-east-1:d2ca0666-d949-47f5-8dc1-2f96f1bc22e3" // Replace with your Cognito Identity Pool ID
        )

        let configuration = AWSServiceConfiguration(
            region: region,
            credentialsProvider: credentialsProvider
        )

        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }

    // MARK: - Photo Upload

    func uploadPhoto(_ image: UIImage, eventId: String, photoIndex: Int) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw S3Error.imageCompressionFailed
        }

        let key = "events/\(eventId)/photo_\(Date().timeIntervalSince1970)_\(photoIndex).jpg"

        return try await withCheckedThrowingContinuation { continuation in
            let uploadRequest = AWSS3PutObjectRequest()!
            uploadRequest.bucket = bucketName
            uploadRequest.key = key
            uploadRequest.contentType = "image/jpeg"
            uploadRequest.contentLength = NSNumber(value: imageData.count)
            // Removed ACL setting - bucket doesn't allow ACLs

            // Create a temporary file for the upload
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

            do {
                try imageData.write(to: tempURL)
                uploadRequest.body = tempURL

                let s3 = AWSS3.default()
                s3.putObject(uploadRequest).continueWith { task in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)

                    DispatchQueue.main.async {
                        if let error = task.error {
                            continuation.resume(throwing: error)
                        } else {
                            // Return just the key instead of full URL
                            continuation.resume(returning: key)
                        }
                    }
                    return nil
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Photo Access

    func getSignedURL(for key: String, expirationMinutes: Int = 60) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let getPreSignedURLRequest = AWSS3GetPreSignedURLRequest()
            getPreSignedURLRequest.bucket = bucketName
            getPreSignedURLRequest.key = key
            getPreSignedURLRequest.httpMethod = .GET
            getPreSignedURLRequest.expires = Date().addingTimeInterval(TimeInterval(expirationMinutes * 60))

            let s3PreSignedURLBuilder = AWSS3PreSignedURLBuilder.default()
            s3PreSignedURLBuilder.getPreSignedURL(getPreSignedURLRequest).continueWith { task in
                DispatchQueue.main.async {
                    if let error = task.error {
                        continuation.resume(throwing: error)
                    } else if let nsurl = task.result, let url = nsurl as URL? {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: S3Error.invalidURL)
                    }
                }
                return nil
            }
        }
    }

    // MARK: - Photo Deletion

    func deletePhoto(key: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let deleteRequest = AWSS3DeleteObjectRequest()!
            deleteRequest.bucket = bucketName
            deleteRequest.key = key

            let s3 = AWSS3.default()
            s3.deleteObject(deleteRequest).continueWith { task in
                DispatchQueue.main.async {
                    if let error = task.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
                return nil
            }
        }
    }

    // MARK: - Batch Operations

    func uploadPhotos(_ images: [UIImage], eventId: String) async throws -> [String] {
        var uploadedURLs: [String] = []

        for (index, image) in images.enumerated() {
            do {
                let url = try await uploadPhoto(image, eventId: eventId, photoIndex: index)
                uploadedURLs.append(url)
            } catch {
                print("Failed to upload photo \(index): \(error)")
                // Continue with other photos even if one fails
            }
        }

        return uploadedURLs
    }

    func deletePhotos(keys: [String]) async {
        for key in keys {
            do {
                try await deletePhoto(key: key)
            } catch {
                print("Failed to delete photo with key \(key): \(error)")
            }
        }
    }

    // MARK: - Profile Picture Upload

    func uploadProfilePicture(_ image: UIImage, coupleId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw S3Error.imageCompressionFailed
        }

        let key = "profile_pictures/\(coupleId).jpg"

        return try await withCheckedThrowingContinuation { continuation in
            let uploadRequest = AWSS3PutObjectRequest()!
            uploadRequest.bucket = bucketName
            uploadRequest.key = key
            uploadRequest.contentType = "image/jpeg"
            uploadRequest.contentLength = NSNumber(value: imageData.count)

            // Create a temporary file for the upload
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

            do {
                try imageData.write(to: tempURL)
                uploadRequest.body = tempURL

                let s3 = AWSS3.default()
                s3.putObject(uploadRequest).continueWith { task in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)

                    DispatchQueue.main.async {
                        if let error = task.error {
                            print("S3 upload error: \(error)")
                            continuation.resume(throwing: error)
                        } else {
                            print("Successfully uploaded profile picture to S3 with key: \(key)")
                            continuation.resume(returning: key)
                        }
                    }
                    return nil
                }
            } catch {
                // Clean up temp file on write error
                try? FileManager.default.removeItem(at: tempURL)
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Helper Methods

    func extractKeyFromURL(_ url: String) -> String? {
        // Extract S3 key from URL like: https://bucket.s3.region.amazonaws.com/key
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host,
              host.contains(bucketName) else {
            return nil
        }

        // Remove leading slash and return the path as the key
        let path = urlComponents.path
        return String(path.dropFirst()) // Remove the leading "/"
    }

    private var regionString: String {
        switch region {
        case .USEast1: return "us-east-1"
        case .USWest1: return "us-west-1"
        case .USWest2: return "us-west-2"
        case .EUWest1: return "eu-west-1"
        default: return "us-east-1"
        }
    }
}

// MARK: - Error Types

enum S3Error: LocalizedError {
    case imageCompressionFailed
    case invalidURL
    case uploadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image"
        case .invalidURL:
            return "Invalid S3 URL"
        case .uploadFailed:
            return "Failed to upload to S3"
        case .deleteFailed:
            return "Failed to delete from S3"
        }
    }
}
