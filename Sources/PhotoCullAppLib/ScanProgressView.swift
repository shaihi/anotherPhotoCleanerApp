import SwiftUI
import PhotoCullCore

struct ScanProgressView: View {
    let progress: ScanProgress?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress?.fraction ?? 0)
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)

            Text(progress?.message ?? "Starting scan…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Cancel") { onCancel() }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 300)
    }
}
