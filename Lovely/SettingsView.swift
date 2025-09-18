import SwiftUI

struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var userSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showAlert = false
    @State private var alertMessage = ""

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

                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(user.uid)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Account Created")
                            Spacer()
                            if let creationDate = user.metadata.creationDate {
                                Text(creationDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Unknown")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if userSession.isInCouple, let couple = userSession.couple {
                    Section("Couple Information") {
                        HStack {
                            Text("Invite Code")
                            Spacer()
                            Text(couple.inviteCode)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Couple ID")
                            Spacer()
                            Text(couple.id ?? "Unknown")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        if let anniversary = couple.anniversary {
                            HStack {
                                Text("Anniversary")
                                Spacer()
                                Text(anniversary.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Profile Picture")
                            Spacer()
                            Text(couple.hasProfilePicture ? "Set" : "Not set")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Relationship Started")
                            Spacer()
                            Text(couple.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Actions") {
                    Button("Sign Out") {
                        signOut()
                    }
                    .foregroundColor(.blue)

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
                        dismiss()
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
        }
    }

    private func signOut() {
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