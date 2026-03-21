import Foundation

public enum CullAction: Sendable, Equatable {
    case keep
    case cull
}

public struct CullRecommendation: Sendable, Equatable {
    public let asset: PhotoAsset
    public let action: CullAction
    public let reasons: [String]
    public let confidence: Double        // 0.0 – 1.0
    public let isOverriddenByUser: Bool
    /// Phase 4: per-signal score breakdown keyed by `QualitySignal.rawValue`. Nil for Phase 1–3 paths.
    public var signalBreakdown: [String: Double]?

    public init(
        asset: PhotoAsset,
        action: CullAction,
        reasons: [String],
        confidence: Double,
        isOverriddenByUser: Bool = false,
        signalBreakdown: [String: Double]? = nil
    ) {
        self.asset = asset
        self.action = action
        self.reasons = reasons
        self.confidence = confidence
        self.isOverriddenByUser = isOverriddenByUser
        self.signalBreakdown = signalBreakdown
    }
}
