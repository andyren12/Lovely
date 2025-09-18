import SwiftUI

struct AnniversarySetupView: View {
    @ObservedObject var userManager: UserManager
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    let onComplete: () -> Void

    // Set date range to reasonable anniversary dates (past dates only)
    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .year, value: -50, to: endDate) ?? endDate
        return startDate...endDate
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.pink)

                    Text("Set Your Anniversary")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("When did your relationship begin? This date will help us celebrate your milestones together.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anniversary Date")
                            .font(.headline)
                            .foregroundColor(.primary)

                        DatePicker(
                            "Select your anniversary",
                            selection: $selectedDate,
                            in: dateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(WheelDatePickerStyle())
                        .frame(maxHeight: 200)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("This date cannot be changed later")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "lock.circle")
                                .foregroundColor(.blue)
                            Text("Both partners will see this date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                Button(action: saveAnniversary) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Set Anniversary")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func saveAnniversary() {
        Task {
            isLoading = true
            do {
                try await userManager.setAnniversary(date: selectedDate)
                onComplete()
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }
}