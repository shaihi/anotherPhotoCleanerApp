import Foundation

public struct ExplanationBuilder: Sendable {
    public init() {}

    /// Attaches human-readable reasons to a recommendation.
    public func explain(recommendation: CullRecommendation, in group: CullGroup) -> CullRecommendation {
        let reasons = buildReasons(for: recommendation, in: group)
        return CullRecommendation(
            asset: recommendation.asset,
            action: recommendation.action,
            reasons: reasons,
            confidence: recommendation.confidence,
            isOverriddenByUser: recommendation.isOverriddenByUser
        )
    }

    private func buildReasons(for recommendation: CullRecommendation, in group: CullGroup) -> [String] {
        switch group.reason {
        case .exactDuplicate:
            return buildExactDuplicateReasons(for: recommendation, in: group)
        case .nearDuplicate:
            return buildNearDuplicateReasons(for: recommendation, in: group)
        case .burst:
            return buildBurstReasons(for: recommendation, in: group)
        }
    }

    private func buildExactDuplicateReasons(
        for recommendation: CullRecommendation, in group: CullGroup
    ) -> [String] {
        var reasons: [String] = []
        let asset = recommendation.asset
        let groupSize = group.members.count

        switch recommendation.action {
        case .keep:
            if asset.isFavorite {
                reasons.append("Kept: marked as a favorite.")
            } else if asset.isEdited {
                reasons.append("Kept: has edits applied.")
            } else if let date = asset.creationDate {
                reasons.append("Kept: newest in group (created \(formattedDate(date))).")
            } else {
                reasons.append("Kept: best available copy in group.")
            }
            reasons.append("This is an exact duplicate group (\(groupSize) identical copies).")

        case .cull:
            reasons.append("Suggested for removal: exact duplicate (SHA-256 match).")
            if !asset.isFavorite && !asset.isEdited {
                reasons.append("This copy has no favorites or edits; a better copy is being kept.")
            }
        }

        return reasons
    }

    private func buildNearDuplicateReasons(
        for recommendation: CullRecommendation, in group: CullGroup
    ) -> [String] {
        let asset = recommendation.asset
        let groupSize = group.members.count

        switch recommendation.action {
        case .keep:
            if asset.isFavorite {
                return ["Kept: favorited photo in a group of \(groupSize) visually similar photos."]
            } else {
                return ["Kept: sharpest in a group of \(groupSize) visually similar photos."]
            }
        case .cull:
            return ["Suggested for removal: visually similar to a better copy in this group."]
        }
    }

    private func buildBurstReasons(
        for recommendation: CullRecommendation, in group: CullGroup
    ) -> [String] {
        let groupSize = group.members.count

        switch recommendation.action {
        case .keep:
            return ["Kept: best shot in a burst sequence of \(groupSize) photos."]
        case .cull:
            return ["Suggested for removal: a better shot was selected from this burst sequence."]
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        ExplanationBuilder.dateFormatter.string(from: date)
    }
}
