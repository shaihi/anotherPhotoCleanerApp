import Foundation

public enum SafetyViolation: Error, Sendable, Equatable {
    case emptyRecommendations
    case recommendationAssetNotInGroup(assetId: String)
    case noKeeperAfterValidation
}

public struct SafetyGuard: Sendable {
    public init() {}

    /// Validates that:
    /// 1. `recommendations` is non-empty
    /// 2. Every recommendation's asset belongs to `group.members`
    /// 3. At least one recommendation is `.keep` (forcing one if needed)
    public func validate(
        recommendations: [CullRecommendation],
        for group: CullGroup
    ) throws -> [CullRecommendation] {
        guard !recommendations.isEmpty else { throw SafetyViolation.emptyRecommendations }

        let memberIds = Set(group.members.map(\.id))
        for rec in recommendations {
            guard memberIds.contains(rec.asset.id) else {
                throw SafetyViolation.recommendationAssetNotInGroup(assetId: rec.asset.id)
            }
        }

        if isSafe(recommendations) { return recommendations }

        // Force first item to .keep via immutable map — never mutate in place
        let first = recommendations[0]
        let forced = CullRecommendation(
            asset: first.asset,
            action: .keep,
            reasons: first.reasons + ["Safety override: preserved to ensure at least one copy remains."],
            confidence: first.confidence,
            isOverriddenByUser: false
        )
        return recommendations.enumerated().map { index, rec in index == 0 ? forced : rec }
    }

    /// Returns true if at least one recommendation is `.keep`.
    /// Call this at any deletion site before acting on a set of recommendations,
    /// including after user overrides are applied.
    public func isSafe(_ recommendations: [CullRecommendation]) -> Bool {
        recommendations.contains { $0.action == .keep }
    }
}
