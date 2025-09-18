import SwiftUI
import UIKit

private enum AppTab: Int, CaseIterable {
    case widgets = 0, calendar = 1, profile = 2

    var title: String {
        switch self {
        case .widgets:  return "Widgets"
        case .calendar: return "Calendar"
        case .profile:  return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .widgets:  return "rectangle.3.group"
        case .calendar: return "calendar"
        case .profile:  return "person.circle"
        }
    }
}

struct MainAppView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager

    @State private var selectedTab: AppTab = .calendar

    var body: some View {
        // ✅ Single parent NavigationStack so large titles/insets work
        NavigationStack {
            TabView(selection: $selectedTab) {
                // ✅ Each page wrapped in PageContainer to guarantee real size
                PageContainer {
                    WidgetsView(authManager: authManager, userManager: userManager)
                }
                .tag(AppTab.widgets)

                PageContainer {
                    CalendarBucketListView(authManager: authManager, userManager: userManager)
                        .environmentObject(deepLinkManager)
                }
                .tag(AppTab.calendar)

                PageContainer {
                    ProfileView(authManager: authManager, userManager: userManager)
                        .environmentObject(deepLinkManager) // keep if Profile needs it
                }
                .tag(AppTab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // native swipe
            .animation(.easeOut(duration: 0.2), value: selectedTab)
            .background(Color(.systemBackground))

            // Your floating island tab bar inserted below content
            .safeAreaInset(edge: .bottom) {
                CustomTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Color.clear)
            }
        }
        .onChange(of: deepLinkManager.shouldNavigateToEvent) {
            if deepLinkManager.shouldNavigateToEvent { selectedTab = .calendar }
        }
        .onAppear { loadUserProfile() }
    }

    private func loadUserProfile() {
        guard let user = authManager.user else { return }
        Task {
            do { try await userManager.loadUserProfile(userId: user.uid) }
            catch { print("Failed to load user profile: \(error)") }
        }
    }
}

private struct PageContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground)) // matches app background
    }
}

private struct CustomTabBar: View {
    @Binding var selected: AppTab

    private let barHeight: CGFloat = 48

    var body: some View {
        ZStack {
            // ISLAND BACKGROUND
            if #available(iOS 15, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
            }

            // BUTTONS (tight internal vertical spacing)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            selected = tab
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        VStack(spacing: 2) {  // tighter label stack spacing
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 17, weight: .semibold)) // slightly smaller icon
                                .symbolVariant(selected == tab ? .fill : .none)
                            Text(tab.title)
                                .font(.caption2)
                                .fontWeight(selected == tab ? .semibold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selected == tab ? Color.purple : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .frame(height: barHeight) // ⬅︎ controls overall island height
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }
}
