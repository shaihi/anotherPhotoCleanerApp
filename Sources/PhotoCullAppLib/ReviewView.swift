import SwiftUI
import PhotoCullCore

struct ReviewView: View {
    var reviewViewModel: ReviewViewModel
    let onReset: () -> Void

    @State private var showingLegend = false

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

            // Footer: Move to Trash button
            if reviewViewModel.cullCount > 0 {
                footerBar
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .overlay(alignment: .bottom) {
            if case .done(let count) = reviewViewModel.deleteState {
                deleteBanner(count: count)
            }
        }
        .alert("Move to Trash?", isPresented: confirmingBinding) {
            Button("Cancel", role: .cancel) { reviewViewModel.cancelDelete() }
            Button("Move to Trash", role: .destructive) {
                Task { await reviewViewModel.confirmDelete() }
            }
        } message: {
            Text("This will move \(reviewViewModel.cullCount) photo(s) to the Trash. You can recover them from the Photos app within 30 days.")
        }
    }

    // MARK: - Subviews

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
            Button {
                showingLegend = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Badge legend")
            .popover(isPresented: $showingLegend, arrowEdge: .bottom) {
                BadgeLegendView()
            }
            Button("New Scan") { onReset() }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var footerBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                if reviewViewModel.deleteState == .deleting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
                Button(role: .destructive) {
                    reviewViewModel.requestDelete()
                } label: {
                    Label("Move \(reviewViewModel.cullCount) to Trash", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(reviewViewModel.deleteState == .deleting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func deleteBanner(count: Int) -> some View {
        Text("\(count) photo\(count == 1 ? "" : "s") moved to Trash")
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.gradient, in: Capsule())
            .padding(.bottom, 52)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut, value: reviewViewModel.deleteState)
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

    // MARK: - Helpers

    private var confirmingBinding: Binding<Bool> {
        Binding(
            get: { reviewViewModel.deleteState == .confirming },
            set: { if !$0 { reviewViewModel.cancelDelete() } }
        )
    }
}
