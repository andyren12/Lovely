import Foundation
import FirebaseFirestore

@MainActor
class UserManager: ObservableObject {
    @Published var currentUserProfile: UserProfile?
    @Published var currentCouple: Couple?
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func createUserProfile(userId: String, firstName: String, lastName: String, birthday: Date) async throws {
        isLoading = true

        let userProfile = UserProfile(userId: userId, firstName: firstName, lastName: lastName, birthday: birthday)

        try db.collection("users").document(userId).setData(from: userProfile)
        currentUserProfile = userProfile
        UserSession.shared.updateUserProfile(userProfile)

        isLoading = false
    }

    func loadUserProfile(userId: String) async throws {
        isLoading = true

        let document = try await db.collection("users").document(userId).getDocument()

        if document.exists {
            currentUserProfile = try document.data(as: UserProfile.self)
            UserSession.shared.updateUserProfile(currentUserProfile)

            // Load couple info if user has one
            if let coupleId = currentUserProfile?.coupleId {
                try await loadCouple(coupleId: coupleId)
            } else {
                // No couple, so we're done loading
                UserSession.shared.setLoading(false)
            }
        } else {
            // No user profile found, not loading anymore
            UserSession.shared.setLoading(false)
        }

        isLoading = false
    }

    func createInviteCode(userId: String) async throws -> String {
        isLoading = true

        let inviteCode = InviteCode.generate()
        let couple = Couple(user1Id: userId, inviteCode: inviteCode)

        // Create couple document
        let coupleRef = try db.collection("couples").addDocument(from: couple)

        // Create empty bucket list for the couple
        let bucketList = BucketList(coupleId: coupleRef.documentID)
        let bucketListRef = try db.collection("bucketLists").addDocument(from: bucketList)

        // Update couple with bucket list ID
        try await coupleRef.updateData([
            "bucketListId": bucketListRef.documentID,
            "updatedAt": Date()
        ])

        // Update user profile with couple ID
        try await db.collection("users").document(userId).updateData([
            "coupleId": coupleRef.documentID,
            "updatedAt": Date()
        ])

        // Update local state
        currentUserProfile?.coupleId = coupleRef.documentID
        var updatedCouple = couple
        updatedCouple.bucketListId = bucketListRef.documentID
        currentCouple = updatedCouple

        UserSession.shared.updateUserProfile(currentUserProfile)
        UserSession.shared.updateCouple(updatedCouple)

        isLoading = false
        return inviteCode
    }

    func joinWithInviteCode(userId: String, inviteCode: String) async throws {
        isLoading = true

        // Find couple with this invite code
        let query = db.collection("couples").whereField("inviteCode", isEqualTo: inviteCode)
        let snapshot = try await query.getDocuments()

        guard let document = snapshot.documents.first else {
            throw NSError(domain: "UserManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code"])
        }

        var couple = try document.data(as: Couple.self)

        // Check if couple is already complete
        if couple.isComplete {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "This invite code has already been used"])
        }

        // Update couple with second user
        couple.user2Id = userId
        couple.updatedAt = Date()

        try document.reference.setData(from: couple)

        // Update user profile with couple ID
        try await db.collection("users").document(userId).updateData([
            "coupleId": document.documentID,
            "updatedAt": Date()
        ])

        // Update local state
        currentUserProfile?.coupleId = document.documentID
        currentCouple = couple

        UserSession.shared.updateUserProfile(currentUserProfile)
        UserSession.shared.updateCouple(couple)

        isLoading = false
    }

    private func loadCouple(coupleId: String) async throws {
        let document = try await db.collection("couples").document(coupleId).getDocument()

        if document.exists {
            var couple = try document.data(as: Couple.self)
            couple.id = document.documentID
            currentCouple = couple
            UserSession.shared.updateCouple(couple)

            // Load partner profile if couple is complete
            if couple.isComplete, let currentUserId = UserSession.shared.userProfile?.userId {
                let partnerId = couple.user1Id == currentUserId ? couple.user2Id : couple.user1Id
                if let partnerId = partnerId {
                    try await loadPartnerProfile(userId: partnerId)
                }
            }
        }

        // Couple loading is complete
        UserSession.shared.setLoading(false)
    }

    private func loadPartnerProfile(userId: String) async throws {
        let document = try await db.collection("users").document(userId).getDocument()

        if document.exists {
            let partnerProfile = try document.data(as: UserProfile.self)
            UserSession.shared.updatePartnerProfile(partnerProfile)
        }
    }

    func setAnniversary(date: Date) async throws {
        guard let coupleId = currentUserProfile?.coupleId else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No couple found"])
        }

        guard let couple = currentCouple, !couple.hasAnniversary else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Anniversary already set"])
        }

        isLoading = true

        // Update couple document with anniversary
        try await db.collection("couples").document(coupleId).updateData([
            "anniversary": date,
            "updatedAt": Date()
        ])

        // Update local state
        var updatedCouple = couple
        updatedCouple.anniversary = date
        updatedCouple.updatedAt = Date()
        currentCouple = updatedCouple

        UserSession.shared.updateCouple(updatedCouple)

        isLoading = false
    }

    func updateCoupleProfilePicture(image: UIImage) async throws -> String {
        guard let coupleId = currentUserProfile?.coupleId else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No couple found"])
        }

        guard let couple = currentCouple else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Couple data not loaded"])
        }

        isLoading = true

        do {
            // Upload image to S3 using dedicated profile picture method
            let uploadedKey = try await S3Manager.shared.uploadProfilePicture(image, coupleId: coupleId)

            // Update couple document with profile picture URL
            try await db.collection("couples").document(coupleId).updateData([
                "profilePictureURL": uploadedKey,
                "updatedAt": Date()
            ])

            // Update local state
            var updatedCouple = couple
            updatedCouple.profilePictureURL = uploadedKey
            updatedCouple.updatedAt = Date()
            currentCouple = updatedCouple

            UserSession.shared.updateCouple(updatedCouple)

            isLoading = false
            return uploadedKey
        } catch {
            isLoading = false
            throw error
        }
    }

    func deleteCoupleProfilePicture() async throws {
        guard let coupleId = currentUserProfile?.coupleId else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No couple found"])
        }

        guard let couple = currentCouple, couple.hasProfilePicture else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No profile picture to delete"])
        }

        isLoading = true

        do {
            // Delete image from S3 if it exists
            if let profilePictureURL = couple.profilePictureURL {
                let keyToDelete: String
                if profilePictureURL.hasPrefix("https://") {
                    // Extract key from URL
                    guard let key = S3Manager.shared.extractKeyFromURL(profilePictureURL) else {
                        throw NSError(domain: "UserManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not extract S3 key"])
                    }
                    keyToDelete = key
                } else {
                    // It's already a key
                    keyToDelete = profilePictureURL
                }

                try await S3Manager.shared.deletePhoto(key: keyToDelete)
            }

            // Update couple document to remove profile picture URL
            try await db.collection("couples").document(coupleId).updateData([
                "profilePictureURL": FieldValue.delete(),
                "updatedAt": Date()
            ])

            // Update local state
            var updatedCouple = couple
            updatedCouple.profilePictureURL = nil
            updatedCouple.updatedAt = Date()
            currentCouple = updatedCouple

            UserSession.shared.updateCouple(updatedCouple)

            isLoading = false
        } catch {
            isLoading = false
            throw error
        }
    }

    func updateUserSettings(hideEventsWithoutPhotos: Bool) async throws {
        guard let userProfile = currentUserProfile else {
            throw NSError(domain: "UserManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No user profile found"])
        }

        isLoading = true

        var updatedSettings = userProfile.settings ?? UserSettings()
        updatedSettings.hideEventsWithoutPhotos = hideEventsWithoutPhotos
        updatedSettings.updatedAt = Date()

        // Update the user profile with new settings
        try await db.collection("users").document(userProfile.userId).updateData([
            "settings": try Firestore.Encoder().encode(updatedSettings)
        ])

        // Update local state
        currentUserProfile?.settings = updatedSettings
        UserSession.shared.updateUserProfile(currentUserProfile)

        isLoading = false
    }

    func clearUserData() {
        currentUserProfile = nil
        currentCouple = nil
        UserSession.shared.clear()
    }
}
