import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var firstName: String
    var lastName: String
    var birthday: Date
    var phoneNumber: String?
    var coupleId: String?
    var settings: UserSettings?
    var createdAt: Date
    var updatedAt: Date

    init(userId: String, firstName: String, lastName: String, birthday: Date, phoneNumber: String? = nil) {
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
        self.birthday = birthday
        self.phoneNumber = phoneNumber
        self.coupleId = nil
        self.settings = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

struct Couple: Codable, Identifiable {
    var id: String?
    var inviteCode: String
    var user1Id: String
    var user2Id: String?
    var bucketListId: String?
    var anniversary: Date?
    var profilePictureURL: String?
    var coupleName: String?
    var createdAt: Date
    var updatedAt: Date

    init(user1Id: String, inviteCode: String) {
        self.id = nil
        self.user1Id = user1Id
        self.inviteCode = inviteCode
        self.user2Id = nil
        self.bucketListId = nil
        self.anniversary = nil
        self.profilePictureURL = nil
        self.coupleName = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isComplete: Bool {
        return user2Id != nil
    }

    var hasAnniversary: Bool {
        return anniversary != nil
    }

    var hasProfilePicture: Bool {
        return profilePictureURL != nil && !profilePictureURL!.isEmpty
    }
}

struct BucketList: Codable, Identifiable {
    var id: String?
    var coupleId: String
    var items: [BucketListItem]
    var createdAt: Date
    var updatedAt: Date

    init(coupleId: String) {
        self.id = nil
        self.coupleId = coupleId
        self.items = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct BucketListItem: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var photoURLs: [String]
    var createdAt: Date
    var completedAt: Date?

    init(title: String, description: String, isCompleted: Bool = false, photoURLs: [String] = [], createdAt: Date = Date(), completedAt: Date? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.photoURLs = photoURLs
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.photoURLs = try container.decodeIfPresent([String].self, forKey: .photoURLs) ?? []
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

struct CalendarEvent: Codable, Identifiable {
    var id: String?
    var title: String
    var description: String
    var date: Date
    var isAllDay: Bool
    var createdAt: Date
    var coupleId: String?
    var photoURLs: [String]
    var comments: [Comment]
    var bucketListItemId: String?

    init(title: String, description: String, date: Date, isAllDay: Bool = false, createdAt: Date = Date(), coupleId: String? = nil, bucketListItemId: String? = nil) {
        self.id = nil
        self.title = title
        self.description = description
        self.date = date
        self.isAllDay = isAllDay
        self.createdAt = createdAt
        self.coupleId = coupleId
        self.photoURLs = []
        self.comments = []
        self.bucketListItemId = bucketListItemId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.date = try container.decode(Date.self, forKey: .date)
        self.isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.coupleId = try container.decodeIfPresent(String.self, forKey: .coupleId)
        // Handle missing photoURLs field for existing events
        self.photoURLs = try container.decodeIfPresent([String].self, forKey: .photoURLs) ?? []
        // Handle missing comments field for existing events
        self.comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
        // Handle missing bucketListItemId field for existing events
        self.bucketListItemId = try container.decodeIfPresent(String.self, forKey: .bucketListItemId)
    }
}

struct Comment: Codable, Identifiable {
    var id: String
    var userId: String
    var userName: String
    var text: String
    var createdAt: Date

    init(userId: String, userName: String, text: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.text = text
        self.createdAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.userId = try container.decode(String.self, forKey: .userId)
        self.userName = try container.decode(String.self, forKey: .userName)
        self.text = try container.decode(String.self, forKey: .text)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct InviteCode {
    static func generate() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

struct UserSettings: Codable {
    var autoTextPartnerOnEventCreation: Bool
    var hideEventsWithoutPhotos: Bool
    var createdAt: Date
    var updatedAt: Date

    init(autoTextPartnerOnEventCreation: Bool = false, hideEventsWithoutPhotos: Bool = false) {
        self.autoTextPartnerOnEventCreation = autoTextPartnerOnEventCreation
        self.hideEventsWithoutPhotos = hideEventsWithoutPhotos
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
