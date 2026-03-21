import Foundation

/// Combines individual quality signals into a single weighted composite score.
public struct CompositeScorer: Sendable {
    public init() {}

    /// Computes a weighted composite score in [0, 1].
    ///
    /// For each signal in `weights`, uses `signals[signal] ?? 0.5` as a neutral
    /// fallback when the signal is not present. The result is normalized by the
    /// total weight so it always falls in [0, 1] regardless of weight magnitudes.
    ///
    /// - Parameters:
    ///   - signals: Scored signal values keyed by `QualitySignal`.
    ///   - weights: Relative importance of each signal.
    /// - Returns: Normalized weighted composite score in [0, 1].
    public func score(signals: [QualitySignal: Double], weights: [QualitySignal: Double]) -> Double {
        let totalWeight = weights.values.reduce(0.0, +)
        guard totalWeight > 0 else { return 0.0 }
        let weightedSum = weights.reduce(0.0) { acc, entry in
            let signalValue = signals[entry.key] ?? 0.5
            return acc + entry.value * signalValue
        }
        return min(1.0, max(0.0, weightedSum / totalWeight))
    }

    /// Returns a dictionary of signal raw name → signal value for use in `signalBreakdown`.
    ///
    /// Only signals present in `weights` are included.
    ///
    /// - Parameters:
    ///   - signals: Scored signal values keyed by `QualitySignal`.
    ///   - weights: The signals to include in the breakdown.
    /// - Returns: Dictionary keyed by `QualitySignal.rawValue`.
    public func breakdown(signals: [QualitySignal: Double], weights: [QualitySignal: Double]) -> [String: Double] {
        var result: [String: Double] = [:]
        for signal in weights.keys {
            result[signal.rawValue] = signals[signal] ?? 0.5
        }
        return result
    }
}
