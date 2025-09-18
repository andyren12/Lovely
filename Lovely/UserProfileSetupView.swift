import SwiftUI

struct UserProfileSetupView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthday = Date()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)

                    Text("Tell us about yourself")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("We'll use this to personalize your experience")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Enter your first name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Enter your last name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birthday")
                            .font(.headline)
                            .foregroundColor(.primary)

                        DatePicker(
                            "Select your birthday",
                            selection: $birthday,
                            in: Date(timeIntervalSince1970: 0)...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(CompactDatePickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: saveProfile) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Continue")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isFormValid || isLoading)

                    Text("You can update this information later in settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func saveProfile() {
        guard let user = authManager.user else { return }

        Task {
            isLoading = true
            do {
                try await userManager.createUserProfile(
                    userId: user.uid,
                    firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    birthday: birthday
                )

                // Mark profile setup as complete
                authManager.completeProfileSetup()
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }
}