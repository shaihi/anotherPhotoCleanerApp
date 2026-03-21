import SwiftUI
import PhotoCullCore

struct GroupCardView: View {
    let group: CullGroup
    let viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                reasonBadge(for: group.reason)
                Text("\(group.members.count) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))

            Divider()

            // Member rows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(group.members, id: \.id) { asset in
                    RecommendationRowView(asset: asset, viewModel: viewModel)
                        .padding(.horizontal, 12)
                    if asset.id != group.members.last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func reasonBadge(for reason: GroupingReason) -> some View {
        let (label, icon, color): (String, String, Color) = switch reason {
        case .exactDuplicate: ("Exact duplicate", "doc.on.doc.fill", .purple)
        case .nearDuplicate:  ("Near duplicate",  "doc.on.doc",      .blue)
        case .burst:          ("Burst",            "camera.fill",     .teal)
        }

        Label(label, systemImage: icon)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
