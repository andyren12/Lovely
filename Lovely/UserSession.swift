import Foundation
import SwiftUI

@MainActor
class UserSession: ObservableObject {
    static let shared = UserSession()

    @Published var userProfile: UserProfile?
    @Published var couple: Couple?
    @Published var partnerProfile: UserProfile?
    @Published var isLoading = true  // Start as loading until data is loaded

    private init() {}

    var isInCouple: Bool {
        userProfile?.coupleId != nil && couple != nil
    }

    var bucketListId: String? {
        couple?.bucketListId
    }

    var coupleId: String? {
        userProfile?.coupleId
    }

    var userSettings: UserSettings? {
        userProfile?.settings
    }

    func updateUserProfile(_ profile: UserProfile?) {
        userProfile = profile
        // If we have user profile data, we're no longer loading
        if profile != nil {
            isLoading = false
        }
    }

    func updateCouple(_ newCouple: Couple?) {
        couple = newCouple
    }

    func updatePartnerProfile(_ profile: UserProfile?) {
        partnerProfile = profile
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    func clear() {
        userProfile = nil
        couple = nil
        partnerProfile = nil
        isLoading = true  // Reset to loading state
    }

    // MARK: - Convenience Properties

    var currentUserId: String? {
        userProfile?.userId
    }

    var currentUserName: String? {
        userProfile?.fullName
    }

    var currentUserFirstName: String? {
        userProfile?.firstName
    }

    var partnerName: String? {
        partnerProfile?.fullName
    }

    var partnerFirstName: String? {
        partnerProfile?.firstName
    }

    var anniversary: Date? {
        couple?.anniversary
    }

    var relationshipStartDate: Date {
        couple?.createdAt ?? Date()
    }

    var coupleProfilePictureURL: String? {
        couple?.profilePictureURL
    }

    var hasCoupleProfilePicture: Bool {
        couple?.hasProfilePicture ?? false
    }

    // MARK: - Convenience Methods

    func displayNamesHeader() -> String {
        guard isInCouple else { return "Profile" }

        if let userFirstName = currentUserFirstName,
           let partnerFirstName = partnerFirstName {
            return "\(userFirstName) + \(partnerFirstName)"
        }

        return "Profile"
    }

    func relationshipDuration() -> String? {
        guard let couple = couple else { return nil }

        let startDate = couple.anniversary ?? couple.createdAt
        let components = Calendar.current.dateComponents([.year, .month], from: startDate, to: Date())

        var parts: [String] = []
        if let years = components.year, years > 0 {
            parts.append("\(years) year\(years == 1 ? "" : "s")")
        }
        if let months = components.month, months > 0 {
            parts.append("\(months) month\(months == 1 ? "" : "s")")
        }

        return parts.isEmpty ? "Less than a month" : parts.joined(separator: ", ")
    }
}