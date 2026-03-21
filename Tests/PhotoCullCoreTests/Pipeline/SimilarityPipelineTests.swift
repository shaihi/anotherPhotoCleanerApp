import XCTest
@testable import PhotoCullCore

// MARK: - Test doubles

/// A preprocessor that always succeeds, returning a ProcessedImage without pixel data.
private struct AlwaysSucceedPreprocessor: ImagePreprocessorProtocol {
    func preprocess(_ asset: PhotoAsset) async throws -> ProcessedImage {
        ProcessedImage(assetId: asset.id, width: 1, height: 1, pixelBuffer: nil)
    }
}

/// A preprocessor that throws for a specific set of asset IDs.
private struct FailingPreprocessor: ImagePreprocessorProtocol {
    let failingIds: Set<String>
    func preprocess(_ asset: PhotoAsset) async throws -> ProcessedImage {
        if failingIds.contains(asset.id) {
            throw TestError.intentional
        }
        return ProcessedImage(assetId: asset.id, width: 1, height: 1, pixelBuffer: nil)
    }
}

/// A feature extractor that returns a fixed vector for every image.
private struct FixedFeatureExtractor: FeatureExtractorProtocol {
    let vector: [Float]
    func extractFeatures(from image: ProcessedImage) async throws -> FeatureVector {
        FeatureVector(values: vector)
    }
}

/// A sharpness analyzer that returns a fixed score for every image.
private struct FixedSharpnessAnalyzer: SharpnessAnalyzerProtocol {
    let value: Double
    func analyzeSharpness(of image: ProcessedImage) async throws -> SharpnessScore {
        SharpnessScore(value: value)
    }
}

/// A feature extractor that throws for a specific set of asset IDs.
private struct FailingFeatureExtractor: FeatureExtractorProtocol {
    let failingIds: Set<String>
    func extractFeatures(from image: ProcessedImage) async throws -> FeatureVector {
        if failingIds.contains(image.assetId) {
            throw TestError.intentional
        }
        return FeatureVector(values: [1, 0])
    }
}

private enum TestError: Error {
    case intentional
}

// MARK: - Tests

final class SimilarityPipelineTests: XCTestCase {

    private func collectResult(from pipeline: ScanPipeline) async throws -> ScanResult {
        var result: ScanResult?
        let stream = await pipeline.scan()
        for try await event in stream {
            if case .completed(let r) = event { result = r }
        }
        guard let result else {
            XCTFail("Pipeline did not emit a completed event")
            throw TestError.intentional
        }
        return result
    }

    // MARK: - Feature extraction failure for one asset

    /// When feature extraction fails for asset "b", all pairs containing "b" are dropped.
    /// The pipeline should continue and produce zero similarity groups (no crash).
    func testFeatureExtractionFailureForOneAssetDropsPairsAndContinues() async throws {
        let now = Date()
        // a and b are within the time window, so they form a candidate pair.
        let a = PhotoAsset(id: "a", creationDate: now)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(5))

        let service = MockPhotoLibraryService(assets: [a, b])

        // Feature extraction fails for "b".
        let backend = AnalysisBackendBundle(
            preprocessor: AlwaysSucceedPreprocessor(),
            sharpnessAnalyzer: FixedSharpnessAnalyzer(value: 0.8),
            featureExtractor: FailingFeatureExtractor(failingIds: ["b"])
        )
        let config = CullConfiguration(
            enableExactDuplicates: false,
            enableNearDuplicates: true,
            nearDuplicateTimeWindowSeconds: 60.0,
            similarityThreshold: 0.15
        )
        let pipeline = ScanPipeline(
            libraryService: service,
            configuration: config,
            analysisBackend: backend
        )

        let result = try await collectResult(from: pipeline)
        // No crash; similarity groups may be zero because the only pair was dropped.
        XCTAssertEqual(result.totalScanned, 2)
        // The pipeline should complete without throwing.
    }

    /// When feature extraction fails for ALL assets, zero similarity groups are produced — no crash.
    func testFeatureExtractionFailureForAllAssetsProducesZeroSimilarityGroups() async throws {
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(10))

        let service = MockPhotoLibraryService(assets: [a, b])
        let backend = AnalysisBackendBundle(
            preprocessor: AlwaysSucceedPreprocessor(),
            sharpnessAnalyzer: FixedSharpnessAnalyzer(value: 0.5),
            featureExtractor: FailingFeatureExtractor(failingIds: ["a", "b"])
        )
        let config = CullConfiguration(
            enableExactDuplicates: false,
            enableNearDuplicates: true,
            nearDuplicateTimeWindowSeconds: 60.0,
            similarityThreshold: 0.15
        )
        let pipeline = ScanPipeline(
            libraryService: service,
            configuration: config,
            analysisBackend: backend
        )

        let result = try await collectResult(from: pipeline)
        XCTAssertEqual(result.groups.count, 0)
        XCTAssertEqual(result.totalScanned, 2)
    }

    /// When near-duplicate detection is enabled with identical feature vectors,
    /// the pair is confirmed and a group is produced.
    func testIdenticalFeatureVectorsProducesSimilarityGroup() async throws {
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(10))

        let service = MockPhotoLibraryService(assets: [a, b])
        // Identical vectors → cosine distance = 0 → confirmed.
        let backend = AnalysisBackendBundle(
            preprocessor: AlwaysSucceedPreprocessor(),
            sharpnessAnalyzer: FixedSharpnessAnalyzer(value: 0.8),
            featureExtractor: FixedFeatureExtractor(vector: [1, 0])
        )
        let config = CullConfiguration(
            enableExactDuplicates: false,
            enableNearDuplicates: true,
            nearDuplicateTimeWindowSeconds: 60.0,
            similarityThreshold: 0.15
        )
        let pipeline = ScanPipeline(
            libraryService: service,
            configuration: config,
            analysisBackend: backend
        )

        let result = try await collectResult(from: pipeline)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups[0].reason, .nearDuplicate)
        XCTAssertEqual(result.recommendations.count, 2)
        XCTAssertTrue(result.recommendations.contains(where: { $0.action == .keep }))
    }

    /// When the analysis backend is nil, the similarity pipeline is skipped entirely.
    func testNilBackendSkipsSimilarityPipeline() async throws {
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(5))

        let service = MockPhotoLibraryService(assets: [a, b])
        let config = CullConfiguration(
            enableExactDuplicates: false,
            enableNearDuplicates: true,
            nearDuplicateTimeWindowSeconds: 60.0,
            similarityThreshold: 0.15
        )
        // No backend → similarity pipeline is skipped.
        let pipeline = ScanPipeline(
            libraryService: service,
            configuration: config,
            analysisBackend: nil
        )

        let result = try await collectResult(from: pipeline)
        XCTAssertEqual(result.groups.count, 0)
    }
}
