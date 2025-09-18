import SwiftUI
import FirebaseAuth

struct PhoneAuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var verificationID = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var codeSent = false

    init(authManager: AuthManager) {
        self.authManager = authManager
        // Check if there's a saved verification ID from a previous session
        if let savedID = UserDefaults.standard.string(forKey: "authVerificationID"),
           !savedID.isEmpty {
            _verificationID = State(initialValue: savedID)
            _codeSent = State(initialValue: true)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            if !codeSent {
                phoneNumberStep
            } else {
                verificationCodeStep
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private var phoneNumberStep: some View {
        VStack(spacing: 20) {
            Text("Enter Your Phone Number")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                TextField("+1 (555) 123-4567", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)

                Button(action: sendCode) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Send Verification Code")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isPhoneNumberValid || isLoading)

                VStack(spacing: 4) {
                    Text("We'll send a verification code to your phone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Standard messaging rates may apply")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
        }
    }

    private var verificationCodeStep: some View {
        VStack(spacing: 20) {
            Text("Enter Verification Code")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                Text("Code sent to \(phoneNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("123456", text: $verificationCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)

                VStack(spacing: 12) {
                    Button(action: verifyCode) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Verify Code")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(verificationCode.count < 6 || isLoading)

                    Button(action: {
                        withAnimation {
                            codeSent = false
                            verificationCode = ""
                            verificationID = ""
                            // Clear saved verification ID
                            UserDefaults.standard.removeObject(forKey: "authVerificationID")
                        }
                    }) {
                        Text("Use Different Number")
                    }
                    .foregroundColor(.blue)
                    .disabled(isLoading)
                }

                Text("Enter the 6-digit code sent to your phone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var isPhoneNumberValid: Bool {
        // Basic phone number validation - should start with + and have at least 10 digits
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return cleaned.hasPrefix("+") && cleaned.count >= 11
    }

    private func sendCode() {
        Task {
            isLoading = true
            do {
                let formattedNumber = formatPhoneNumber(phoneNumber)
                verificationID = try await authManager.sendVerificationCode(to: formattedNumber)
                withAnimation {
                    codeSent = true
                }
            } catch let error as NSError {
                // Handle specific Firebase Auth errors
                switch error.code {
                case 17010: // FIRAuthErrorCodeInvalidPhoneNumber
                    alertMessage = "Invalid phone number format. Please check and try again."
                case 17025: // FIRAuthErrorCodeTooManyRequests
                    alertMessage = "Too many requests. Please try again later."
                case 17999: // FIRAuthErrorCodeInternalError
                    alertMessage = "An internal error occurred. Please try again."
                default:
                    alertMessage = error.localizedDescription
                }
                showAlert = true
            }
            isLoading = false
        }
    }

    private func verifyCode() {
        Task {
            isLoading = true
            do {
                try await authManager.verifyPhoneNumber(verificationID: verificationID, verificationCode: verificationCode)
                // Clear saved verification ID on successful verification
                UserDefaults.standard.removeObject(forKey: "authVerificationID")
            } catch let error as NSError {
                // Handle specific Firebase Auth errors
                switch error.code {
                case 17044: // FIRAuthErrorCodeInvalidVerificationCode
                    alertMessage = "Invalid verification code. Please check and try again."
                case 17020: // FIRAuthErrorCodeSessionExpired
                    alertMessage = "Verification code expired. Please request a new code."
                    // Clear expired verification ID
                    UserDefaults.standard.removeObject(forKey: "authVerificationID")
                    withAnimation {
                        codeSent = false
                        verificationID = ""
                        verificationCode = ""
                    }
                case 17025: // FIRAuthErrorCodeTooManyRequests
                    alertMessage = "Too many failed attempts. Please try again later."
                default:
                    alertMessage = error.localizedDescription
                }
                showAlert = true
            }
            isLoading = false
        }
    }

    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if cleaned.hasPrefix("+") {
            return cleaned
        } else if cleaned.hasPrefix("1") {
            return "+\(cleaned)"
        } else {
            return "+1\(cleaned)"
        }
    }
}

