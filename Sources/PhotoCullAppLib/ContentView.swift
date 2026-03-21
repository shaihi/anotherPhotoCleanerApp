import SwiftUI
import PhotoCullCore

struct ContentView: View {
    @State private var scanViewModel = ScanViewModel()

    var body: some View {
        switch scanViewModel.status {
        case .idle:
            LandingView(onScan: { scanViewModel.startScan() })
        case .scanning(let progress):
            ScanProgressView(progress: progress, onCancel: { scanViewModel.cancelScan() })
        case .done(let result):
            ReviewView(
                reviewViewModel: ReviewViewModel(result: result),
                onReset: { scanViewModel.resetScan() }
            )
        case .failed(let message):
            VStack(spacing: 16) {
                Text("Scan failed").font(.headline)
                Text(message).foregroundStyle(.secondary)
                Button("Try Again") { scanViewModel.resetScan() }
            }
            .padding()
            .frame(minWidth: 500, minHeight: 300)
        }
    }
}

private struct LandingView: View {
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("PhotoCull")
                .font(.largeTitle.bold())
            Text("Scan your library to find duplicate and similar photos.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Scan Library") { onScan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 350)
    }
}
