import SwiftUI

struct ContentView: View {
    // Pull managers from the environment (provided by LovelyApp)
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var deepLinkManager: DeepLinkManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.needsProfileSetup {
                    UserProfileSetupView(authManager: authManager, userManager: userManager)
                        .environmentObject(deepLinkManager)
                } else if authManager.isNewUser {
                    PartnerInviteView(authManager: authManager, userManager: userManager)
                        .environmentObject(deepLinkManager)
                } else {
                    MainAppView(authManager: authManager, userManager: userManager)
                        .environmentObject(deepLinkManager)
                }
            } else {
                // If not authenticated, show AuthView; it will read managers from env
                AuthView()
                    // If AuthView expects env objects, they’re already injected from LovelyApp.
                    // Keep these two lines only if AuthView explicitly requires them:
                    .environmentObject(authManager)
                    .environmentObject(deepLinkManager)
            }
        }
        // Helpful during debugging: see which branch you’re in
        .onAppear {
            print("✅ ContentView appeared. isAuthenticated=\(authManager.isAuthenticated), needsProfileSetup=\(authManager.needsProfileSetup), isNewUser=\(authManager.isNewUser)")
        }
    }
}

#Preview {
    // Preview needs mock environment objects or it will crash
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(UserManager())
        .environmentObject(DeepLinkManager.shared)
}
