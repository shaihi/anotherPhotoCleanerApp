import SwiftUI

struct BadgeLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Badge Legend")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("Recommendation Badges") {
                        legendRow(
                            icon: "checkmark.circle.fill", iconColor: .green,
                            label: "Keep",
                            detail: "The pipeline recommends keeping this photo."
                        )
                        legendRow(
                            icon: "trash.circle", iconColor: .orange,
                            label: "Cull",
                            detail: "The pipeline recommends removing this photo."
                        )
                        legendRow(
                            icon: "person.crop.circle.badge.checkmark", iconColor: .blue,
                            label: "Keep (you)",
                            detail: "You overrode the recommendation — marked to keep."
                        )
                        legendRow(
                            icon: "person.crop.circle.badge.minus", iconColor: .blue,
                            label: "Cull (you)",
                            detail: "You overrode the recommendation — marked to remove."
                        )
                    }

                    Divider().padding(.vertical, 4)

                    section("Scores") {
                        legendRow(
                            icon: "star.fill", iconColor: .primary,
                            label: "Quality %",
                            detail: "Weighted composite of sharpness, exposure, subject quality, and resolution. Higher is better."
                        )
                        legendRow(
                            icon: "checkmark.seal", iconColor: .secondary,
                            label: "Confidence %",
                            detail: "How certain the algorithm is about its recommendation. Low confidence means scores were close."
                        )
                    }

                    Divider().padding(.vertical, 4)

                    section("Signal Bars") {
                        legendRow(
                            icon: "circle.fill", iconColor: .blue,
                            label: "Sharpness",
                            detail: "Edge clarity via Laplacian variance. Higher = crisper focus."
                        )
                        legendRow(
                            icon: "circle.fill", iconColor: .yellow,
                            label: "Exposure",
                            detail: "Histogram balance. Penalises underexposed (dark) and blown-out highlights."
                        )
                        legendRow(
                            icon: "circle.fill", iconColor: .green,
                            label: "Subject",
                            detail: "Vision framework saliency — how prominent the main subject is."
                        )
                        legendRow(
                            icon: "circle.fill", iconColor: .purple,
                            label: "Resolution",
                            detail: "Pixel dimensions relative to the highest-resolution photo in the group."
                        )
                    }

                    Divider().padding(.vertical, 4)

                    section("Row Actions") {
                        legendRow(
                            icon: "trash", iconColor: .orange,
                            label: "Mark for removal",
                            detail: "Override a Keep recommendation to Cull."
                        )
                        legendRow(
                            icon: "arrow.uturn.backward", iconColor: .green,
                            label: "Mark to keep",
                            detail: "Override a Cull recommendation to Keep."
                        )
                        legendRow(
                            icon: "xmark.circle", iconColor: .secondary,
                            label: "Reset",
                            detail: "Undo your override and restore the pipeline recommendation."
                        )
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 480)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
        content()
    }

    private func legendRow(
        icon: String,
        iconColor: Color,
        label: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 18)
                .font(.caption)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
