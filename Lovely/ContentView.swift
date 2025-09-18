//
//  ContentView.swift
//  Lovely
//
//  Created by Andy Ren on 9/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var userManager = UserManager()
    @StateObject private var deepLinkManager = DeepLinkManager.shared

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
                AuthView()
                    .environmentObject(authManager)
                    .environmentObject(deepLinkManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
