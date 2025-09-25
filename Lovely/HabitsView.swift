import SwiftUI
import FirebaseAuth

struct HabitsView: View {
    @StateObject private var habitManager = HabitManager()
    @StateObject private var userSession = UserSession.shared
    @State private var selectedDate = Date()
    @State private var dailyStatuses: [DailyHabitStatus] = []
    @State private var isLoading = true
    @State private var showingCreateHabit = false

    private var canNavigateToFuture: Bool {
        !Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with title and plus button
            HStack {
                Text("Habits")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showingCreateHabit = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            datePickerSection

            if isLoading {
                loadingView
            } else if dailyStatuses.isEmpty {
                emptyStateView
            } else {
                habitListView
            }

            Spacer()
        }
        .sheet(isPresented: $showingCreateHabit) {
            CreateHabitView(habitManager: habitManager) {
                loadHabitsForDate()
            }
        }
        .onAppear {
            loadHabitsForDate()
        }
        .onChange(of: selectedDate) {
            loadHabitsForDate()
        }
    }

    private var datePickerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.purple)
                }

                Spacer()

                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(canNavigateToFuture ? .purple : .gray)
                }
                .disabled(!canNavigateToFuture)
            }
            .padding(.horizontal)

            if !Calendar.current.isDateInToday(selectedDate) {
                Button("Jump to Today") {
                    selectedDate = Date()
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading habits...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Habits Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first habit to start tracking together")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showingCreateHabit = true }) {
                Text("Create Habit")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var habitListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(dailyStatuses, id: \.habit.id) { status in
                    HabitRowView(
                        status: status,
                        onToggleUser1: { toggleHabitCompletion(status: status, isUser1: true) },
                        onToggleUser2: { toggleHabitCompletion(status: status, isUser1: false) }
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func loadHabitsForDate() {
        guard let coupleId = userSession.coupleId else { return }

        Task {
            isLoading = true

            do {
                let statuses = try await habitManager.getDailyHabitStatuses(for: coupleId, date: selectedDate)

                await MainActor.run {
                    dailyStatuses = statuses
                    isLoading = false
                }
            } catch {
                print("Failed to load habits: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func toggleHabitCompletion(status: DailyHabitStatus, isUser1: Bool) {
        guard let habitId = status.habit.id,
              let couple = userSession.couple else { return }

        let userId = isUser1 ? couple.user1Id : (couple.user2Id ?? "")
        let currentlyCompleted = isUser1 ? status.user1Completed : status.user2Completed

        // Optimistic UI update - immediately update the local state
        updateLocalCompletionStatus(habitId: habitId, isUser1: isUser1, completed: !currentlyCompleted)

        Task {
            do {
                if currentlyCompleted {
                    try await habitManager.markHabitIncomplete(habitId: habitId, userId: userId, date: selectedDate)
                } else {
                    try await habitManager.markHabitComplete(habitId: habitId, userId: userId, date: selectedDate)
                }
                // No need to reload - optimistic update already applied
            } catch {
                print("Failed to toggle habit completion: \(error)")

                // Revert optimistic update on error
                updateLocalCompletionStatus(habitId: habitId, isUser1: isUser1, completed: currentlyCompleted)

                // Optionally show error to user
                // TODO: Add error handling UI
            }
        }
    }

    private func updateLocalCompletionStatus(habitId: String, isUser1: Bool, completed: Bool) {
        if let index = dailyStatuses.firstIndex(where: { $0.habit.id == habitId }) {
            let habit = dailyStatuses[index].habit
            let date = dailyStatuses[index].date

            // Update the completion status
            let updatedStatus = DailyHabitStatus(
                habit: habit,
                date: date,
                user1Completed: isUser1 ? completed : dailyStatuses[index].user1Completed,
                user2Completed: isUser1 ? dailyStatuses[index].user2Completed : completed,
                user1CompletedAt: isUser1 ? (completed ? Date() : nil) : dailyStatuses[index].user1CompletedAt,
                user2CompletedAt: isUser1 ? dailyStatuses[index].user2CompletedAt : (completed ? Date() : nil)
            )

            dailyStatuses[index] = updatedStatus
        }
    }
}

struct HabitRowView: View {
    let status: DailyHabitStatus
    let onToggleUser1: () -> Void
    let onToggleUser2: () -> Void

    @StateObject private var userSession = UserSession.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.habit.title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if !status.habit.description.isEmpty {
                        Text(status.habit.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                completionBadge
            }

            HStack(spacing: 16) {
                userCompletionButton(
                    userName: getUser1Name(),
                    isCompleted: status.user1Completed,
                    action: onToggleUser1
                )

                if let user2Id = userSession.couple?.user2Id, !user2Id.isEmpty {
                    userCompletionButton(
                        userName: getUser2Name(),
                        isCompleted: status.user2Completed,
                        action: onToggleUser2
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var completionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.isBothCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(status.isBothCompleted ? .green : .secondary)

            Text(status.completionStatus)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.isBothCompleted ? .green : .secondary)
        }
    }

    private func userCompletionButton(userName: String, isCompleted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .purple : .secondary)

                Text(userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .purple : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? Color.purple.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isCompleted ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getUser1Name() -> String {
        guard let couple = userSession.couple,
              let userProfile = userSession.userProfile else { return "User 1" }

        if userProfile.userId == couple.user1Id {
            return userProfile.firstName
        } else {
            return userSession.partnerProfile?.firstName ?? "Partner"
        }
    }

    private func getUser2Name() -> String {
        guard let couple = userSession.couple,
              let userProfile = userSession.userProfile else { return "User 2" }

        if userProfile.userId != couple.user1Id {
            return userProfile.firstName
        } else {
            return userSession.partnerProfile?.firstName ?? "Partner"
        }
    }
}
