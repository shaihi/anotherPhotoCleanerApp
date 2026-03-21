import SwiftUI
import PhotoCullCore

enum ScanStatus: Equatable {
    case idle
    case scanning(ScanProgress?)
    case done(ScanResult)
    case failed(String)
}

@MainActor
@Observable
final class ScanViewModel {
    var status: ScanStatus = .idle

    private var scanTask: Task<Void, Never>?

    var isScanning: Bool {
        if case .scanning = status { return true }
        return false
    }

    func startScan() {
        guard !isScanning else { return }
        status = .scanning(nil)

        scanTask = Task {
            let pipeline = ScanPipeline(libraryService: MockPhotoLibraryService())
            do {
                for try await event in await pipeline.scan() {
                    switch event {
                    case .progress(let progress):
                        status = .scanning(progress)
                    case .completed(let result):
                        status = .done(result)
                    }
                }
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        status = .idle
    }

    func resetScan() {
        cancelScan()
    }
}
