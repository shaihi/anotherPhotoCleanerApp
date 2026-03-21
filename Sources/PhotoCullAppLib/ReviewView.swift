import SwiftUI
import PhotoCullCore

struct ReviewView: View {
    var reviewViewModel: ReviewViewModel
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            summaryHeader

            Divider()

            if reviewViewModel.groups.isEmpty {
                emptyState
            } else {
                groupList
            }
        }
        .frame(minWidth: 560, minHeight: 400)
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review Results")
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(reviewViewModel.keepCount) keep", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(reviewViewModel.cullCount) remove", systemImage: "trash.circle")
                        .foregroundStyle(.orange)
                    Label("\(reviewViewModel.groups.count) group(s)", systemImage: "rectangle.3.group")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            Spacer()
            Button("New Scan") { onReset() }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(reviewViewModel.groups) { group in
                    GroupCardView(group: group, viewModel: reviewViewModel)
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No duplicate groups found.")
                .foregroundStyle(.secondary)
            Button("New Scan") { onReset() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
