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
    let decisionStore: UserDefaultsReviewDecisionStore = UserDefaultsReviewDecisionStore()

    private var scanTask: Task<Void, Never>?

    var isScanning: Bool {
        if case .scanning = status { return true }
        return false
    }

    func startScan() {
        guard !isScanning else { return }
        status = .scanning(nil)

        let store = decisionStore
        scanTask = Task {
            var config = CullConfiguration.default
            config.enableNearDuplicates = true
            let service = MockPhotoLibraryService()
            let backend = AnalysisBackend.makeDefault(dataLoader: service.loadImageData(for:))
            let pipeline = ScanPipeline(
                libraryService: service,
                configuration: config,
                analysisBackend: backend,
                decisionStore: store
            )
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
