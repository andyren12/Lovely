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
    var habitIds: [String]
    var maxHabits: Int
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
        self.habitIds = []
        self.maxHabits = 5 // Free tier limit
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

// MARK: - Habit Tracker Models

struct Habit: Codable, Identifiable {
    var id: String?
    var title: String
    var description: String
    var coupleId: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool

    init(title: String, description: String, coupleId: String) {
        self.id = nil
        self.title = title
        self.description = description
        self.coupleId = coupleId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
    }
}


struct DailyHabitStatus {
    let habit: Habit
    let date: Date
    let user1Completed: Bool
    let user2Completed: Bool
    let user1CompletedAt: Date?
    let user2CompletedAt: Date?

    var isBothCompleted: Bool {
        return user1Completed && user2Completed
    }

    var completionStatus: String {
        if isBothCompleted {
            return "Both completed"
        } else if user1Completed || user2Completed {
            return "One completed"
        } else {
            return "Not completed"
        }
    }
}

// MARK: - Daily Completion Models

struct DailyHabitCompletions: Codable, Identifiable {
    var id: String? // Will be "coupleId_yyyy-MM-dd"
    var coupleId: String
    var date: Date // Normalized to start of day
    var habitCompletions: [String: UserCompletions] // habitId -> UserCompletions
    var createdAt: Date
    var updatedAt: Date

    init(coupleId: String, date: Date) {
        self.id = "\(coupleId)_\(Self.dateString(from: date))"
        self.coupleId = coupleId
        self.date = Calendar.current.startOfDay(for: date)
        self.habitCompletions = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct UserCompletions: Codable {
    var user1Completed: Bool
    var user2Completed: Bool
    var user1CompletedAt: Date?
    var user2CompletedAt: Date?

    init() {
        self.user1Completed = false
        self.user2Completed = false
        self.user1CompletedAt = nil
        self.user2CompletedAt = nil
    }

    init(user1Completed: Bool, user2Completed: Bool, user1CompletedAt: Date?, user2CompletedAt: Date?) {
        self.user1Completed = user1Completed
        self.user2Completed = user2Completed
        self.user1CompletedAt = user1CompletedAt
        self.user2CompletedAt = user2CompletedAt
    }
}
