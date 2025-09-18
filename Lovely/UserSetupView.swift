import SwiftUI

struct UserSetupView: View {
    @ObservedObject var authManager: AuthManager
    @State private var displayName = ""
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.pink)

                    Text("Welcome to Lovely!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Let's set up your profile")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("Display Name (Optional)", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)

                    if let phoneNumber = authManager.user?.phoneNumber {
                        HStack {
                            Text("Phone:")
                            Spacer()
                            Text(phoneNumber)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: completeSetup) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Continue")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)

                    Text("You can update your profile later in settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    private func completeSetup() {
        Task {
            isLoading = true

            // Update display name if provided
            if !displayName.isEmpty {
                let changeRequest = authManager.user?.createProfileChangeRequest()
                changeRequest?.displayName = displayName
                try? await changeRequest?.commitChanges()
            }

            authManager.completeUserSetup()
            isLoading = false
        }
    }
}