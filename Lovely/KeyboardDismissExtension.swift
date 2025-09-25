import SwiftUI
import UIKit

// Global extension to add keyboard dismissal functionality to any View
extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    func hideKeyboardOnSwipe() -> some View {
        self.gesture(
            DragGesture()
                .onChanged { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }

    func dismissKeyboard() -> some View {
        self.hideKeyboardOnTap()
            .hideKeyboardOnSwipe()
    }
}