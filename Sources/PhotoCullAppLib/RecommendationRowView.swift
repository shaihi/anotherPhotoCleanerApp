import SwiftUI
import PhotoCullCore

struct RecommendationRowView: View {
    let asset: PhotoAsset
    let viewModel: ReviewViewModel

    @State private var showingPreview = false

    var body: some View {
        let action = viewModel.effectiveAction(for: asset.id)
        let overridden = viewModel.isOverridden(for: asset.id)
        let rec = viewModel.recommendation(for: asset.id)

        HStack(alignment: .top, spacing: 12) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor(for: action))
                .frame(width: 4)

            // Thumbnail slot — tap to open full-size preview
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 48, height: 48)

                if let image = viewModel.cachedThumbnail(for: asset.id) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showingPreview = true }
            .help("Click to preview")
            .task { await viewModel.loadThumbnail(for: asset.id) }
            .sheet(isPresented: $showingPreview) {
                ThumbnailPreviewSheet(
                    assetId: asset.id,
                    image: viewModel.cachedThumbnail(for: asset.id),
                    onDismiss: { showingPreview = false }
                )
            }

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Keep / cull badge
                    actionBadge(action: action, overridden: overridden)

                    if let confidence = rec?.confidence {
                        Text(String(format: "%.0f%%", confidence * 100))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    Spacer()

                    // Toggle button
                    Button {
                        if action == .keep {
                            viewModel.overrideAction(assetId: asset.id, to: .cull)
                        } else {
                            viewModel.overrideAction(assetId: asset.id, to: .keep)
                        }
                    } label: {
                        Image(systemName: action == .keep ? "trash" : "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(action == .keep ? Color.orange : Color.green)
                    .help(action == .keep ? "Mark for removal" : "Mark to keep")

                    if overridden {
                        Button {
                            viewModel.resetOverride(for: asset.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Reset to pipeline recommendation")
                    }
                }

                Text(asset.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let reasons = rec?.reasons, !reasons.isEmpty {
                    Text(reasons.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                if let breakdown = viewModel.signalBreakdown(for: asset.id), !breakdown.isEmpty {
                    SignalBreakdownView(breakdown: breakdown)
                        .padding(.top, 2)
                }

                // Safety-blocked message (shown under the triggering row)
                if let blocked = viewModel.blockedMessage {
                    Text(blocked)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 8)
        .background(rowBackground(for: action))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func actionBadge(action: CullAction, overridden: Bool) -> some View {
        if overridden {
            Label(
                action == .keep ? "Keep (you)" : "Cull (you)",
                systemImage: action == .keep
                    ? "person.crop.circle.badge.checkmark"
                    : "person.crop.circle.badge.minus"
            )
            .font(.caption2.bold())
            .foregroundStyle(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.12), in: Capsule())
        } else {
            Label(
                action == .keep ? "Keep" : "Cull",
                systemImage: action == .keep ? "checkmark.circle.fill" : "trash.circle"
            )
            .font(.caption2.bold())
            .foregroundStyle(action == .keep ? Color.green : Color.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                (action == .keep ? Color.green : Color.orange).opacity(0.12),
                in: Capsule()
            )
        }
    }

    private func accentColor(for action: CullAction) -> Color {
        action == .keep ? .green : .orange
    }

    private func rowBackground(for action: CullAction) -> Color {
        (action == .keep ? Color.green : Color.orange).opacity(0.06)
    }
}

// MARK: - Thumbnail preview sheet

private struct ThumbnailPreviewSheet: View {
    let assetId: String
    let image: NSImage?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 480, maxHeight: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 240, height: 240)
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
            }
            Text(assetId)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Done") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 300)
    }
}
