import SwiftUI

struct PartnerInviteView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @State private var inviteCode = ""
    @State private var generatedInviteCode = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showInviteCode = false
    @State private var showAnniversarySetup = false

    var body: some View {
        NavigationView {
            if showAnniversarySetup {
                AnniversarySetupView(userManager: userManager) {
                    completeOnboarding()
                }
            } else {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.purple)

                        Text("Connect with your partner")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Share your Lovely experience together")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if showInviteCode {
                        inviteCodeSection
                    } else {
                        optionButtons
                    }

                    Spacer()

                    if !showInviteCode {
                        Button("Skip for now") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .navigationBarHidden(true)
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private var optionButtons: some View {
        VStack(spacing: 20) {
            Button(action: createInvite) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                    Text("Invite your partner")
                        .fontWeight(.semibold)
                    Text("Create an invite code to share")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple, lineWidth: 2)
                )
                .cornerRadius(12)
            }
            .disabled(isLoading)

            VStack(spacing: 16) {
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    TextField("Enter invite code", text: $inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .textCase(.uppercase)

                    Button(action: joinWithCode) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Join with code")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inviteCode.isEmpty || isLoading)
                }
                .padding()
                .background(Color.purple.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple, lineWidth: 2)
                )
                .cornerRadius(12)
            }
        }
    }

    private var inviteCodeSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Share this code with your partner")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(generatedInviteCode)
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .onTapGesture {
                        copyToClipboard()
                    }

                Button(action: copyToClipboard) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 12) {
                Text("Instructions:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Share this code with your partner")
                    Text("2. They can enter it when setting up their account")
                    Text("3. Once they join, you'll both be connected!")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Button("Continue") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func createInvite() {
        guard let user = authManager.user else { return }

        Task {
            isLoading = true
            do {
                let code = try await userManager.createInviteCode(userId: user.uid)
                generatedInviteCode = code
                withAnimation {
                    showInviteCode = true
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }

    private func joinWithCode() {
        guard let user = authManager.user else { return }

        Task {
            isLoading = true
            do {
                try await userManager.joinWithInviteCode(userId: user.uid, inviteCode: inviteCode.uppercased())
                // Show anniversary setup after successful join
                withAnimation {
                    showAnniversarySetup = true
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = generatedInviteCode
        // Could add a toast notification here
    }

    private func completeOnboarding() {
        // Mark onboarding as complete - this will transition to main app
        authManager.isNewUser = false
    }
}
