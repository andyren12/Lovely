import SwiftUI

struct MainAppView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            BucketListView(authManager: authManager, userManager: userManager)
                .tabItem {
                    Image(systemName: "list.clipboard")
                    Text("Bucket List")
                }
                .tag(0)

            CalendarView(authManager: authManager, userManager: userManager)
                .environmentObject(deepLinkManager)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)

            ProfileView(authManager: authManager, userManager: userManager)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .onChange(of: deepLinkManager.shouldNavigateToEvent) {
            if deepLinkManager.shouldNavigateToEvent {
                selectedTab = 1 // Switch to Calendar tab
            }
        }
        .accentColor(.purple)
        .onAppear {
            loadUserProfile()
        }
    }

    private func loadUserProfile() {
        guard let user = authManager.user else { return }

        Task {
            do {
                try await userManager.loadUserProfile(userId: user.uid)
            } catch {
                print("Failed to load user profile: \(error)")
            }
        }
    }
}