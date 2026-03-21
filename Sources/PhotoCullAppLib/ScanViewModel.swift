import SwiftUI
import PhotoCullCore

@MainActor
@Observable
final class ScanViewModel {
    var statusText: String = "Ready to scan."
    var isScanning: Bool = false

    private var scanTask: Task<Void, Never>?

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        statusText = "Starting scan…"

        scanTask = Task {
            defer { isScanning = false }
            let pipeline = ScanPipeline(libraryService: MockPhotoLibraryService())
            do {
                for try await event in await pipeline.scan() {
                    switch event {
                    case .progress(let progress):
                        statusText = progress.message
                    case .completed(let result):
                        statusText = "Done. Found \(result.groups.count) duplicate group(s) in \(result.totalScanned) photo(s)."
                    }
                }
            } catch {
                statusText = "Error: \(error.localizedDescription)"
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }
}
