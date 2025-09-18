import SwiftUI

struct BucketListItemPicker: View {
    @ObservedObject var bucketListManager: BucketListManager
    @StateObject private var userSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedBucketListItemId: String?
    let onItemSelected: (BucketListItem?) -> Void

    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Loading bucket list...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if bucketListManager.bucketList?.items.isEmpty ?? true {
                    emptyStateView
                } else {
                    bucketListView
                }
            }
            .navigationTitle("Choose Bucket List Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        selectedBucketListItemId = nil
                        onItemSelected(nil)
                        dismiss()
                    }
                    .disabled(selectedBucketListItemId == nil)
                }
            }
        }
        .onAppear {
            loadBucketList()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Bucket List Items")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Create some bucket list items first to link them to your events")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bucketListView: some View {
        List {
            if let bucketList = bucketListManager.bucketList {
                ForEach(bucketList.items) { item in
                    BucketListPickerItemRow(
                        item: item,
                        isSelected: selectedBucketListItemId == item.id,
                        onTap: {
                            selectedBucketListItemId = item.id
                            onItemSelected(item)
                            dismiss()
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    private func loadBucketList() {
        guard let bucketListId = userSession.bucketListId else {
            isLoading = false
            return
        }

        Task {
            await bucketListManager.loadBucketList(for: bucketListId)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct BucketListPickerItemRow: View {
    let item: BucketListItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Completion indicator
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isCompleted ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .strikethrough(item.isCompleted)
                        .opacity(item.isCompleted ? 0.6 : 1.0)

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .strikethrough(item.isCompleted)
                            .opacity(item.isCompleted ? 0.6 : 1.0)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.pink)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}