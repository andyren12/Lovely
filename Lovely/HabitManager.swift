import Foundation
import FirebaseFirestore

@MainActor
class HabitManager: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    // MARK: - Habit Management

    func loadHabits(for coupleId: String) async throws {
        isLoading = true

        // Step 1: Get couple document with habit IDs
        let coupleDoc = try await db.collection("couples").document(coupleId).getDocument()
        guard let coupleData = coupleDoc.data(),
              let habitIds = coupleData["habitIds"] as? [String] else {
            habits = []
            isLoading = false
            return
        }

        guard !habitIds.isEmpty else {
            habits = []
            isLoading = false
            return
        }

        // Step 2: Get all habit documents in parallel
        let fetchedHabits = try await withThrowingTaskGroup(of: Habit?.self) { group in
            for habitId in habitIds {
                group.addTask {
                    do {
                        let doc = try await self.db.collection("habits").document(habitId).getDocument()
                        guard doc.exists else { return nil }
                        var habit = try doc.data(as: Habit.self)
                        habit.id = doc.documentID
                        return habit.isActive ? habit : nil // Filter inactive
                    } catch {
                        print("Failed to fetch habit \(habitId): \(error)")
                        return nil
                    }
                }
            }

            var results: [Habit] = []
            for try await habit in group {
                if let habit = habit {
                    results.append(habit)
                }
            }
            return results
        }

        // Step 3: Maintain order from habitIds array
        habits = habitIds.compactMap { habitId in
            fetchedHabits.first { $0.id == habitId }
        }

        isLoading = false
    }

    func createHabit(title: String, description: String, coupleId: String) async throws -> Habit {
        isLoading = true

        // Check habit limit
        let coupleDoc = try await db.collection("couples").document(coupleId).getDocument()
        let coupleData = coupleDoc.data() ?? [:]
        let habitIds = coupleData["habitIds"] as? [String] ?? []
        let maxHabits = coupleData["maxHabits"] as? Int ?? 5

        guard habitIds.count < maxHabits else {
            isLoading = false
            throw NSError(domain: "HabitManager", code: 429, userInfo: [
                NSLocalizedDescriptionKey: "Maximum of \(maxHabits) habits allowed. Upgrade to create more."
            ])
        }

        let habit = Habit(title: title, description: description, coupleId: coupleId)

        // Step 1: Create habit document
        let documentRef = try db.collection("habits").addDocument(from: habit)
        var createdHabit = habit
        createdHabit.id = documentRef.documentID

        // Step 2: Add habit ID to couple document
        try await db.collection("couples").document(coupleId).updateData([
            "habitIds": FieldValue.arrayUnion([documentRef.documentID])
        ])

        // Step 3: Add to local array
        habits.append(createdHabit)

        isLoading = false
        return createdHabit
    }

    func updateHabit(_ habit: Habit) async throws {
        guard let habitId = habit.id else {
            throw NSError(domain: "HabitManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Habit ID is missing"])
        }

        isLoading = true

        var updatedHabit = habit
        updatedHabit.updatedAt = Date()

        try db.collection("habits").document(habitId).setData(from: updatedHabit)

        // Update local array
        if let index = habits.firstIndex(where: { $0.id == habitId }) {
            habits[index] = updatedHabit
        }

        isLoading = false
    }

    func deleteHabit(_ habit: Habit) async throws {
        guard let habitId = habit.id else {
            throw NSError(domain: "HabitManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Habit ID is missing"])
        }

        isLoading = true

        // Step 1: Mark as inactive instead of deleting (soft delete)
        var updatedHabit = habit
        updatedHabit.isActive = false
        updatedHabit.updatedAt = Date()

        try db.collection("habits").document(habitId).setData(from: updatedHabit)

        // Step 2: Remove from couple's habitIds array
        try await db.collection("couples").document(habit.coupleId).updateData([
            "habitIds": FieldValue.arrayRemove([habitId])
        ])

        // Step 3: Remove from local array
        habits.removeAll { $0.id == habitId }

        isLoading = false
    }

    // MARK: - Completion Management

    func markHabitComplete(habitId: String, userId: String, date: Date = Date()) async throws {
        guard let coupleId = UserSession.shared.coupleId else {
            throw NSError(domain: "HabitManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No couple ID found"])
        }

        try await updateHabitCompletion(habitId: habitId, userId: userId, completed: true, coupleId: coupleId, date: date)
    }

    func markHabitIncomplete(habitId: String, userId: String, date: Date = Date()) async throws {
        guard let coupleId = UserSession.shared.coupleId else {
            throw NSError(domain: "HabitManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No couple ID found"])
        }

        try await updateHabitCompletion(habitId: habitId, userId: userId, completed: false, coupleId: coupleId, date: date)
    }

    private func updateHabitCompletion(habitId: String, userId: String, completed: Bool, coupleId: String, date: Date) async throws {
        let dailyDocId = "\(coupleId)_\(DailyHabitCompletions.dateString(from: date))"
        let docRef = db.collection("dailyHabitCompletions").document(dailyDocId)

        // Use Firestore transaction to handle concurrent updates
        _ = try await db.runTransaction { transaction, errorPointer in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            var dailyCompletions: DailyHabitCompletions

            if document.exists {
                // Update existing document
                do {
                    dailyCompletions = try document.data(as: DailyHabitCompletions.self)
                } catch {
                    // Handle decoding error - create new document
                    dailyCompletions = DailyHabitCompletions(coupleId: coupleId, date: date)
                }
            } else {
                // Create new document
                dailyCompletions = DailyHabitCompletions(coupleId: coupleId, date: date)
            }

            // Get or create habit completion entry
            var habitCompletion = dailyCompletions.habitCompletions[habitId] ?? UserCompletions()

            // Determine which user to update based on couple structure
            let couple = UserSession.shared.couple
            let isUser1 = userId == couple?.user1Id

            if isUser1 {
                habitCompletion.user1Completed = completed
                habitCompletion.user1CompletedAt = completed ? Date() : nil
            } else {
                habitCompletion.user2Completed = completed
                habitCompletion.user2CompletedAt = completed ? Date() : nil
            }

            // Update the daily completions
            dailyCompletions.habitCompletions[habitId] = habitCompletion
            dailyCompletions.updatedAt = Date()

            // Save back to Firestore
            do {
                try transaction.setData(from: dailyCompletions, forDocument: docRef)
            } catch let updateError as NSError {
                errorPointer?.pointee = updateError
                return nil
            }

            return nil
        }
    }

    func getDailyHabitStatuses(for coupleId: String, date: Date = Date()) async throws -> [DailyHabitStatus] {
        // Get habits using existing reference-based approach
        let habits = try await getHabitsForCouple(coupleId: coupleId)

        // Get daily completions document
        let dailyDocId = "\(coupleId)_\(DailyHabitCompletions.dateString(from: date))"
        let completionDoc = try await db.collection("dailyHabitCompletions").document(dailyDocId).getDocument()

        var dailyCompletions: DailyHabitCompletions?
        if completionDoc.exists {
            dailyCompletions = try? completionDoc.data(as: DailyHabitCompletions.self)
        }

        // Build status array
        return habits.map { habit in
            let habitCompletion = dailyCompletions?.habitCompletions[habit.id ?? ""] ?? UserCompletions()

            return DailyHabitStatus(
                habit: habit,
                date: Calendar.current.startOfDay(for: date),
                user1Completed: habitCompletion.user1Completed,
                user2Completed: habitCompletion.user2Completed,
                user1CompletedAt: habitCompletion.user1CompletedAt,
                user2CompletedAt: habitCompletion.user2CompletedAt
            )
        }
    }

    private func getHabitsForCouple(coupleId: String) async throws -> [Habit] {
        // Get couple document with habit IDs
        let coupleDoc = try await db.collection("couples").document(coupleId).getDocument()
        guard let coupleData = coupleDoc.data(),
              let habitIds = coupleData["habitIds"] as? [String] else {
            return []
        }

        guard !habitIds.isEmpty else { return [] }

        // Get all habit documents in parallel
        let fetchedHabits = try await withThrowingTaskGroup(of: Habit?.self) { group in
            for habitId in habitIds {
                group.addTask {
                    do {
                        let doc = try await self.db.collection("habits").document(habitId).getDocument()
                        guard doc.exists else { return nil }
                        var habit = try doc.data(as: Habit.self)
                        habit.id = doc.documentID
                        return habit.isActive ? habit : nil
                    } catch {
                        print("Failed to fetch habit \(habitId): \(error)")
                        return nil
                    }
                }
            }

            var results: [Habit] = []
            for try await habit in group {
                if let habit = habit {
                    results.append(habit)
                }
            }
            return results
        }

        // Maintain order from habitIds array
        return habitIds.compactMap { habitId in
            fetchedHabits.first { $0.id == habitId }
        }
    }

    // MARK: - Helper Methods

    func clearErrorMessage() {
        errorMessage = nil
    }
}