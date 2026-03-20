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

    public init(
        asset: PhotoAsset,
        action: CullAction,
        reasons: [String],
        confidence: Double,
        isOverriddenByUser: Bool = false
    ) {
        self.asset = asset
        self.action = action
        self.reasons = reasons
        self.confidence = confidence
        self.isOverriddenByUser = isOverriddenByUser
    }
}
