import SwiftUI

struct CreateHabitView: View {
    @ObservedObject var habitManager: HabitManager
    @StateObject private var userSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss
    let onHabitCreated: (() -> Void)?

    init(habitManager: HabitManager, onHabitCreated: (() -> Void)? = nil) {
        self.habitManager = habitManager
        self.onHabitCreated = onHabitCreated
    }

    @State private var title = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let maxTitleLength = 50
    private let maxDescriptionLength = 200

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Habit title", text: $title)
                        .onChange(of: title) {
                            if title.count > maxTitleLength {
                                title = String(title.prefix(maxTitleLength))
                            }
                        }

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: description) {
                            if description.count > maxDescriptionLength {
                                description = String(description.prefix(maxDescriptionLength))
                            }
                        }
                } header: {
                    Text("Habit Details")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create a habit that both you and your partner can track daily.")

                        HStack {
                            Text("Title: \(title.count)/\(maxTitleLength)")
                            Spacer()
                            if !description.isEmpty {
                                Text("Description: \(description.count)/\(maxDescriptionLength)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Couples Tracking", systemImage: "heart.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)

                        Text("Both partners can mark this habit as complete independently. The habit is fully completed only when both partners have marked it done.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createHabit) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .disabled(isCreating)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func createHabit() {
        guard let coupleId = userSession.coupleId,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            isCreating = true

            do {
                _ = try await habitManager.createHabit(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    coupleId: coupleId
                )

                await MainActor.run {
                    onHabitCreated?()
                    dismiss()
                }
            } catch {
                print("Failed to create habit: \(error)")
                await MainActor.run {
                    if let nsError = error as NSError?, nsError.code == 429 {
                        errorMessage = nsError.localizedDescription
                    } else {
                        errorMessage = "Failed to create habit. Please try again."
                    }
                    isCreating = false
                }
            }
        }
    }
}