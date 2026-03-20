/// Sharpness score from 0.0 (completely blurry) to 1.0 (perfectly sharp).
public struct SharpnessScore: Sendable, Equatable {
    public let value: Double
    public init(value: Double) { self.value = max(0, min(1, value)) }
}

/// Computes a sharpness score for a preprocessed image using Laplacian variance.
/// Phase 3 implementation: MetalSharpness (Metal compute shader).
public protocol SharpnessAnalyzerProtocol: Sendable {
    func analyzeSharpness(of image: ProcessedImage) async throws -> SharpnessScore
}
