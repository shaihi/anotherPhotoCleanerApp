import Foundation

public struct ExactDuplicateRanker: Sendable {
    public init() {}

    /// Ranks group members: favorite > edited > newest creation date.
    /// Returns one .keep (the best) and .cull for all others.
    public func rank(group: CullGroup) -> [CullRecommendation] {
        let sorted = group.members.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            if a.isEdited != b.isEdited { return a.isEdited }
            let aDate = a.creationDate ?? .distantPast
            let bDate = b.creationDate ?? .distantPast
            return aDate > bDate
        }

        let count = sorted.count
        return sorted.enumerated().map { index, asset in
            let action: CullAction = index == 0 ? .keep : .cull
            // All exact duplicates are clear-cut; .keep gets slightly lower confidence
            // when the group is large (more copies = more ambiguity about which to keep).
            let confidence: Double = index == 0
                ? max(0.5, 1.0 - (Double(count - 1) * 0.05))
                : 0.9
            return CullRecommendation(
                asset: asset,
                action: action,
                reasons: [],      // ExplanationBuilder fills these in
                confidence: confidence
            )
        }
    }
}
