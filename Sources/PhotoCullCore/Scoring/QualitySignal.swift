import Foundation

/// The discrete quality dimensions used for composite scoring.
public enum QualitySignal: String, CaseIterable, Sendable, Hashable {
    case sharpness
    case exposure
    case subjectQuality
    case resolution
}

/// A single scored quality signal for one asset.
public struct SignalValue: Sendable, Equatable {
    public let signal: QualitySignal
    /// Normalized quality value, clamped to [0, 1].
    public let value: Double

    public init(signal: QualitySignal, value: Double) {
        self.signal = signal
        self.value = min(1.0, max(0.0, value))
    }
}
