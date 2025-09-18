import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Lovely")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                PhoneAuthView(authManager: authManager)
            }
            .padding()
        }
    }
}

#Preview {
    AuthView()
}