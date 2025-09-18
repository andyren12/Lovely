import SwiftUI

struct BucketListView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var userManager: UserManager
    @StateObject private var bucketListManager = BucketListManager()
    @StateObject private var userSession = UserSession.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var showingAddItem = false
    @State private var showAlert = false
    @State private var selectedItem: BucketListItem?

    private var bucketListId: String? {
        userSession.bucketListId
    }

    private var isInCouple: Bool {
        userSession.isInCouple
    }

    private var incompleteItems: [BucketListItem] {
        bucketListManager.bucketItems.filter { !$0.isCompleted }
    }

    private var completedItems: [BucketListItem] {
        bucketListManager.bucketItems.filter { $0.isCompleted }
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
                // Incomplete Items Section
                if !incompleteItems.isEmpty {
                    Section("To Do") {
                        ForEach(incompleteItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                BucketListItemRow(
                                    item: item,
                                    onToggle: {
                                        completeItem(item)
                                    },
                                    onComplete: {
                                        completeItem(item)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { offsets in
                            if let bucketListId = bucketListId {
                                deleteIncompleteItems(offsets: offsets, bucketListId: bucketListId)
                            }
                        }
                    }
                }

                // Completed Items Section
                if !completedItems.isEmpty {
                    Section("Completed") {
                        ForEach(completedItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                BucketListItemRow(
                                    item: item,
                                    onToggle: {
                                        uncompleteItem(item)
                                    },
                                    onComplete: {
                                        toggleItemCompletion(item)
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { offsets in
                            if let bucketListId = bucketListId {
                                deleteCompletedItems(offsets: offsets, bucketListId: bucketListId)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await refreshBucketList()
        }
        .listStyle(PlainListStyle())
        .sheet(item: $selectedItem) { item in
            BucketListItemDetailView(bucketListItem: .constant(item), bucketListManager: bucketListManager)
        }
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

    private func completeItem(_ item: BucketListItem) {
        guard let bucketListId = userSession.bucketListId else { return }

        Task {
            do {
                print("Completing item: \(item.title), current status: \(item.isCompleted)")

                // Create completed version of the item (same as detail view)
                var completedItem = item
                completedItem.isCompleted = true
                completedItem.completedAt = Date()

                // Update using the same method as detail view
                try await bucketListManager.updateBucketListItem(bucketListId: bucketListId, item: completedItem)
                print("Successfully updated item completion in bucket list manager")

                // Create a calendar event for the completed item
                if let coupleId = userSession.coupleId {
                    try await calendarManager.createEventFromBucketListItem(completedItem, coupleId: coupleId)
                    print("Successfully created calendar event")
                }
            } catch {
                print("Failed to complete item: \(error)")
            }
        }
    }

    private func uncompleteItem(_ item: BucketListItem) {
        guard let bucketListId = userSession.bucketListId else { return }

        Task {
            do {
                print("Uncompleting item: \(item.title), current status: \(item.isCompleted)")

                // Remove the calendar event if it exists
                if let coupleId = userSession.coupleId {
                    try await calendarManager.deleteEventForBucketListItem(item.id, coupleId: coupleId)
                    print("Successfully removed calendar event")
                }

                // Create incomplete version of the item (same as detail view)
                var incompleteItem = item
                incompleteItem.isCompleted = false
                incompleteItem.completedAt = nil

                // Update using the same method as detail view
                try await bucketListManager.updateBucketListItem(bucketListId: bucketListId, item: incompleteItem)
                print("Successfully updated item completion in bucket list manager")
            } catch {
                print("Failed to uncomplete item: \(error)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet, bucketListId: String) {
        bucketListManager.deleteBucketItems(at: offsets, bucketListId: bucketListId)
    }

    private func deleteIncompleteItems(offsets: IndexSet, bucketListId: String) {
        // Convert section-specific offsets to full list offsets
        let itemsToDelete = Array(offsets).compactMap { index in
            index < incompleteItems.count ? incompleteItems[index] : nil
        }

        // Find the actual indices in the full bucket list
        let fullListOffsets = IndexSet(itemsToDelete.compactMap { item in
            bucketListManager.bucketItems.firstIndex(where: { $0.id == item.id })
        })

        bucketListManager.deleteBucketItems(at: fullListOffsets, bucketListId: bucketListId)
    }

    private func deleteCompletedItems(offsets: IndexSet, bucketListId: String) {
        // Convert section-specific offsets to full list offsets
        let itemsToDelete = Array(offsets).compactMap { index in
            index < completedItems.count ? completedItems[index] : nil
        }

        // Find the actual indices in the full bucket list
        let fullListOffsets = IndexSet(itemsToDelete.compactMap { item in
            bucketListManager.bucketItems.firstIndex(where: { $0.id == item.id })
        })

        bucketListManager.deleteBucketItems(at: fullListOffsets, bucketListId: bucketListId)
    }

    private func refreshBucketList() async {
        guard let bucketListId = bucketListId else { return }
        await bucketListManager.refreshBucketList(for: bucketListId)
    }
}

struct BucketListItemRow: View {
    let item: BucketListItem
    let onToggle: () -> Void
    let onComplete: () -> Void

    @State private var showingCompletionDialog = false
    @State private var showingUncompleteConfirmation = false

    var body: some View {
        HStack {
            Button(action: {
                if item.isCompleted {
                    showingUncompleteConfirmation = true
                } else {
                    showingCompletionDialog = true
                }
            }) {
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
        .alert("Mark as Complete?", isPresented: $showingCompletionDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Mark Complete") {
                onComplete()
            }
        } message: {
            Text("This will mark '\(item.title)' as completed and create a post on your profile.")
        }
        .alert("Mark as Incomplete?", isPresented: $showingUncompleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Mark Incomplete", role: .destructive) {
                onToggle()
            }
        } message: {
            Text("This will mark the item as incomplete and delete the post from your profile.")
        }
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