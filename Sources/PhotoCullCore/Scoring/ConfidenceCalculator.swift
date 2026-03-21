import Foundation

/// Derives recommendation confidence from score separation and similarity strength.
public struct ConfidenceCalculator: Sendable {
    public init() {}

    /// Computes keeper recommendation confidence.
    ///
    /// - Parameters:
    ///   - keeperScore: Composite score of the recommended keeper.
    ///   - nextBestScore: Composite score of the next-best member.
    ///   - similarityConfidence: Confidence derived from pair similarity distances.
    ///   - separationScale: Delta at which score separation reaches full weight (default 0.3).
    /// - Returns: Confidence value clamped to [0.5, 0.95].
    public func confidence(
        keeperScore: Double,
        nextBestScore: Double,
        similarityConfidence: Double,
        separationScale: Double = 0.3
    ) -> Double {
        let scoreDelta = keeperScore - nextBestScore
        let signalSeparation = min(1.0, scoreDelta / max(separationScale, 1e-9))
        let raw = 0.6 * signalSeparation + 0.4 * similarityConfidence
        return raw.clamped(to: 0.5...0.95)
    }

    /// Returns true if confidence falls below the configured threshold.
    ///
    /// - Parameters:
    ///   - confidence: The computed confidence value.
    ///   - threshold: Minimum acceptable confidence for a cull recommendation.
    public func isSuppressed(confidence: Double, threshold: Double) -> Bool {
        confidence < threshold
    }
}

// MARK: - Clamping helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
