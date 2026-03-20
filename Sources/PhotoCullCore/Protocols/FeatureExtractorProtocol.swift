/// Placeholder for a CNN feature vector. Phase 2 will use VNGenerateImageFeaturePrintRequest.
public struct FeatureVector: Sendable, Equatable {
    public let values: [Float]
    public init(values: [Float]) { self.values = values }
}

/// Extracts a feature vector from a preprocessed image for near-duplicate detection.
/// Phase 2 implementation: Vision framework (VNGenerateImageFeaturePrintRequest).
public protocol FeatureExtractorProtocol: Sendable {
    func extractFeatures(from image: ProcessedImage) async throws -> FeatureVector
}
