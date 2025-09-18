import SwiftUI

struct BucketListView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var bucketListManager = BucketListManager()
    @StateObject private var userSession = UserSession.shared
    @State private var showingAddItem = false
    @State private var showAlert = false

    private var bucketListId: String? {
        userSession.bucketListId
    }

    private var isInCouple: Bool {
        userSession.isInCouple
    }

    var body: some View {
        NavigationView {
            Group {
                if userSession.isLoading || userManager.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if bucketListManager.isLoading && bucketListManager.bucketItems.isEmpty {
                    ProgressView("Loading bucket list...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isInCouple && bucketListId != nil {
                    bucketListContent
                } else {
                    noCoupleView
                }
            }
            .navigationTitle("Bucket List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!isInCouple)
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddBucketItemView { title, description in
                    if let bucketListId = bucketListId {
                        addBucketItem(title: title, description: description, bucketListId: bucketListId)
                    }
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(bucketListManager.errorMessage ?? "An unknown error occurred")
            }
            .onAppear {
                loadBucketListIfNeeded()
            }
            .onChange(of: userSession.bucketListId) {
                loadBucketListIfNeeded()
            }
            .onChange(of: bucketListManager.errorMessage) {
                showAlert = bucketListManager.errorMessage != nil
            }
        }
    }

    private var bucketListContent: some View {
        List {
            if bucketListManager.bucketItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)

                    Text("Your Bucket List is Empty")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add dreams and goals you want to achieve together")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .listRowSeparator(.hidden)
            } else {
                ForEach(bucketListManager.bucketItems) { item in
                    BucketListItemRow(item: item) {
                        toggleItemCompletion(item)
                    }
                }
                .onDelete { offsets in
                    if let bucketListId = bucketListId {
                        deleteItems(offsets: offsets, bucketListId: bucketListId)
                    }
                }
            }
        }
        .refreshable {
            await refreshBucketList()
        }
        .listStyle(PlainListStyle())
    }

    private var noCoupleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Partner Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You need to create or join a couple to share a bucket list")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Private Methods

    private func loadBucketListIfNeeded() {
        guard let bucketListId = bucketListId else { return }

        Task {
            await bucketListManager.loadBucketList(for: bucketListId)
        }
    }

    private func addBucketItem(title: String, description: String, bucketListId: String) {
        Task {
            do {
                try await bucketListManager.addBucketItem(
                    title: title,
                    description: description,
                    bucketListId: bucketListId
                )
            } catch {
                // Error is handled in BucketListManager
            }
        }
    }

    private func toggleItemCompletion(_ item: BucketListItem) {
        Task {
            do {
                try await bucketListManager.toggleItemCompletion(item)
            } catch {
                // Error is handled in BucketListManager
            }
        }
    }

    private func deleteItems(offsets: IndexSet, bucketListId: String) {
        bucketListManager.deleteBucketItems(at: offsets, bucketListId: bucketListId)
    }

    private func refreshBucketList() async {
        guard let bucketListId = bucketListId else { return }
        await bucketListManager.refreshBucketList(for: bucketListId)
    }
}

struct BucketListItemRow: View {
    let item: BucketListItem
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let completedAt = item.completedAt {
                    Text("Completed: \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

struct AddBucketItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    let onAdd: (String, String) -> Void

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Dream or Goal") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add to Bucket List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
}