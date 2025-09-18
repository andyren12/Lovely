import FirebaseAuth
import SwiftUI
import FirebaseFirestore

class CustomAuthUIDelegate: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        window.rootViewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        window.rootViewController?.dismiss(animated: flag, completion: completion)
    }
}

@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isNewUser = false
    @Published var needsProfileSetup = false

    private let authUIDelegate = CustomAuthUIDelegate()

    init() {
        user = Auth.auth().currentUser
        isAuthenticated = user != nil

        if user != nil {
            Task {
                await checkUserProfileStatus()
            }
        }

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil

            if user != nil {
                Task {
                    await self?.checkUserProfileStatus()
                }
            } else {
                self?.isNewUser = false
                self?.needsProfileSetup = false
            }
        }
    }

    func sendVerificationCode(to phoneNumber: String) async throws -> String {
        do {
            // Use the UIDelegate to handle reCAPTCHA fallback when APNs is not available
            let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: authUIDelegate)

            // Save verification ID for app restarts
            UserDefaults.standard.set(verificationID, forKey: "authVerificationID")

            return verificationID
        } catch let error as NSError {
            print("Phone verification error: \(error.localizedDescription)")
            print("Error code: \(error.code)")
            print("Error domain: \(error.domain)")
            print("Error userInfo: \(error.userInfo)")

            // Handle specific error cases
            switch error.code {
            case AuthErrorCode.quotaExceeded.rawValue:
                print("SMS quota exceeded - Firebase might be using reCAPTCHA instead")
            case AuthErrorCode.missingAppCredential.rawValue:
                print("APNs certificate not configured properly")
            case AuthErrorCode.invalidPhoneNumber.rawValue:
                print("Invalid phone number format")
            case AuthErrorCode.internalError.rawValue:
                print("Internal Firebase error - check configuration:")
                print("1. Is Phone Auth enabled in Firebase Console?")
                print("2. Is GoogleService-Info.plist correct and recent?")
                print("3. Is APNs certificate uploaded to Firebase?")
                print("4. Is the phone number format correct? (\(phoneNumber))")
            default:
                print("Unhandled error code: \(error.code)")
            }

            throw error
        }
    }

    func verifyPhoneNumber(verificationID: String, verificationCode: String) async throws {
        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: verificationCode
            )

            let result = try await Auth.auth().signIn(with: credential)
            user = result.user

            // Check if this is a new user (first time signing in)
            if result.additionalUserInfo?.isNewUser == true {
                isNewUser = true
                needsProfileSetup = true
            } else {
                await checkUserProfileStatus()
            }
        } catch let error as NSError {
            print("Phone verification error: \(error.localizedDescription)")
            print("Error code: \(error.code)")
            throw error
        }
    }


    func completeProfileSetup() {
        needsProfileSetup = false
    }

    func completeUserSetup() {
        isNewUser = false
    }

    private func checkUserProfileStatus() async {
        guard let user = user else { return }

        let db = Firestore.firestore()

        do {
            let document = try await db.collection("users").document(user.uid).getDocument()

            if document.exists {
                let userData = try document.data(as: UserProfile.self)
                needsProfileSetup = false

                // Check if user has completed partner setup (has coupleId)
                isNewUser = userData.coupleId == nil
            } else {
                isNewUser = true
                needsProfileSetup = true
            }
        } catch {
            print("Error checking user profile status: \(error)")
            isNewUser = true
            needsProfileSetup = true
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        user = nil
    }

    func deleteAccount() async throws {
        guard let user = user else { return }
        try await user.delete()
        self.user = nil
    }
}
