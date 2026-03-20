import Foundation

/// Named container for the three analysis protocol implementations.
/// Returned by `AnalysisBackend.makeDefault(dataLoader:)`.
/// Use named property access instead of tuple indexing.
public struct AnalysisBackendBundle: @unchecked Sendable {
    public let preprocessor: any ImagePreprocessorProtocol
    public let sharpnessAnalyzer: any SharpnessAnalyzerProtocol
    public let featureExtractor: any FeatureExtractorProtocol

    public init(
        preprocessor: some ImagePreprocessorProtocol,
        sharpnessAnalyzer: some SharpnessAnalyzerProtocol,
        featureExtractor: some FeatureExtractorProtocol
    ) {
        self.preprocessor = preprocessor
        self.sharpnessAnalyzer = sharpnessAnalyzer
        self.featureExtractor = featureExtractor
    }
}
