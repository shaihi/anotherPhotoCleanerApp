import Foundation

public enum ScanPhase: Sendable, Equatable, CaseIterable {
    case fetchingAssets
    case hashing
    case grouping
    case ranking
    case complete
}

public struct ScanProgress: Sendable, Equatable {
    public let phase: ScanPhase
    public let processed: Int
    public let total: Int
    public let message: String

    public var fraction: Double {
        total > 0 ? min(1.0, Double(processed) / Double(total)) : 0
    }

    public init(phase: ScanPhase, processed: Int, total: Int, message: String) {
        self.phase = phase
        self.processed = processed
        self.total = total
        self.message = message
    }
}
