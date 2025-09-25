import SwiftUI
import FirebaseFirestore

struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @ObservedObject private var userSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var hideEventsWithoutPhotos = false
    @State private var originalHideEventsWithoutPhotos = false
    @State private var hasAppeared = false
    @State private var showingAccountInfo = false

    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    Button("Account Info") {
                        showingAccountInfo = true
                    }
                    .foregroundColor(.primary)
                }

                Section("Preferences") {
                    Toggle("Hide events without photos", isOn: $hideEventsWithoutPhotos)
                }

                Section("Actions") {
                    Button("Sign Out") {
                        signOut()
                    }
                    .foregroundColor(.purple)

                    Button("Delete Account") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        saveSettingsAndDismiss()
                    }
                }
            }
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAccountInfo) {
                AccountInfoView(authManager: authManager, userManager: userManager)
            }
        }
        .onAppear {
            loadUserSettings()
            hasAppeared = true
        }
    }

    private func loadUserSettings() {
        hideEventsWithoutPhotos = userSession.userSettings?.hideEventsWithoutPhotos ?? false
        originalHideEventsWithoutPhotos = hideEventsWithoutPhotos
    }

    private func saveSettingsAndDismiss() {
        // Check if settings have changed
        if hideEventsWithoutPhotos != originalHideEventsWithoutPhotos {
            Task {
                do {
                    try await userManager.updateUserSettings(hideEventsWithoutPhotos: hideEventsWithoutPhotos)
                    print("✅ Settings saved successfully")
                    await MainActor.run {
                        dismiss()
                    }
                } catch {
                    print("❌ Settings save failed: \(error)")
                    await MainActor.run {
                        alertMessage = "Failed to save settings: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        } else {
            // No changes, just dismiss
            dismiss()
        }
    }

    private func signOut() {
        // Save any pending settings changes before signing out
        if hideEventsWithoutPhotos != originalHideEventsWithoutPhotos {
            Task {
                do {
                    try await userManager.updateUserSettings(hideEventsWithoutPhotos: hideEventsWithoutPhotos)
                    await MainActor.run {
                        performSignOut()
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to save settings before sign out: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        } else {
            performSignOut()
        }
    }

    private func performSignOut() {
        do {
            try authManager.signOut()
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await authManager.deleteAccount()
                dismiss()
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// MARK: - Account Info View
struct AccountInfoView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @ObservedObject private var userSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Account Information") {
                    if let user = authManager.user {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(userSession.userProfile?.fullName ?? "Not set")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Phone Number")
                            Spacer()
                            Text(user.phoneNumber ?? "No phone number")
                                .foregroundColor(.secondary)
                        }

                        if let userProfile = userSession.userProfile {
                            HStack {
                                Text("Birthday")
                                Spacer()
                                Text(userProfile.birthday.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if userSession.isInCouple, let couple = userSession.couple {
                    Section("Couple Information") {
                        if let anniversary = couple.anniversary {
                            HStack {
                                Text("Anniversary")
                                Spacer()
                                Text(anniversary.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}