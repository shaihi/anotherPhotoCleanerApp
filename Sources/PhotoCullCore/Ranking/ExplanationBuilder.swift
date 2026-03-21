import Foundation

public struct ExplanationBuilder: Sendable {
    public init() {}

    /// Attaches human-readable reasons to a recommendation.
    public func explain(recommendation: CullRecommendation, in group: CullGroup) -> CullRecommendation {
        explain(recommendation: recommendation, in: group, keeperBreakdown: nil)
    }

    /// Attaches human-readable reasons to a recommendation.
    /// Pass the keeper's `signalBreakdown` for accurate delta values in cull explanations.
    public func explain(
        recommendation: CullRecommendation,
        in group: CullGroup,
        keeperBreakdown: [String: Double]?
    ) -> CullRecommendation {
        let reasons = buildReasons(for: recommendation, in: group, keeperBreakdown: keeperBreakdown)
        return CullRecommendation(
            asset: recommendation.asset,
            action: recommendation.action,
            reasons: reasons,
            confidence: recommendation.confidence,
            isOverriddenByUser: recommendation.isOverriddenByUser
        )
    }

    private func buildReasons(
        for recommendation: CullRecommendation,
        in group: CullGroup,
        keeperBreakdown: [String: Double]? = nil
    ) -> [String] {
        switch group.reason {
        case .exactDuplicate:
            return buildExactDuplicateReasons(for: recommendation, in: group)
        case .nearDuplicate:
            return buildNearDuplicateReasons(for: recommendation, in: group, keeperBreakdown: keeperBreakdown)
        case .burst:
            return buildBurstReasons(for: recommendation, in: group, keeperBreakdown: keeperBreakdown)
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
        for recommendation: CullRecommendation,
        in group: CullGroup,
        keeperBreakdown: [String: Double]?
    ) -> [String] {
        let asset = recommendation.asset
        let groupSize = group.members.count

        // Phase 4: use signal breakdown when available.
        if let breakdown = recommendation.signalBreakdown, !breakdown.isEmpty {
            return buildSignalReasons(
                for: recommendation,
                breakdown: breakdown,
                keeperBreakdown: keeperBreakdown,
                groupSize: groupSize,
                groupType: "near-duplicate"
            )
        }

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
        for recommendation: CullRecommendation,
        in group: CullGroup,
        keeperBreakdown: [String: Double]?
    ) -> [String] {
        let groupSize = group.members.count

        // Phase 4: use signal breakdown when available.
        if let breakdown = recommendation.signalBreakdown, !breakdown.isEmpty {
            return buildSignalReasons(
                for: recommendation,
                breakdown: breakdown,
                keeperBreakdown: keeperBreakdown,
                groupSize: groupSize,
                groupType: "burst"
            )
        }

        switch recommendation.action {
        case .keep:
            return ["Kept: best shot in a burst sequence of \(groupSize) photos."]
        case .cull:
            return ["Suggested for removal: a better shot was selected from this burst sequence."]
        }
    }

    // MARK: - Phase 4 signal-level reasons

    private func buildSignalReasons(
        for recommendation: CullRecommendation,
        breakdown: [String: Double],
        keeperBreakdown: [String: Double]?,
        groupSize: Int,
        groupType: String
    ) -> [String] {
        // Check for suppression reasons that were already written into `reasons` by BestShotRanker.
        if !recommendation.reasons.isEmpty {
            return recommendation.reasons
        }

        switch recommendation.action {
        case .keep:
            let top = topSignal(in: breakdown)
            let formatted = formatValue(top.value)
            return ["Kept: \(top.name) (\(formatted)) — best in group of \(groupSize) \(groupType) photos."]
        case .cull:
            let topDelta = topDeltaSignal(in: breakdown, keeperBreakdown: keeperBreakdown)
            let formatted = formatValue(topDelta.value)
            return ["Suggested for removal: lower \(topDelta.name) (\(formatted) vs \(formatValue(topDelta.keeperValue)))."]
        }
    }

    /// Returns the signal name and value with the highest value in the breakdown.
    private func topSignal(in breakdown: [String: Double]) -> (name: String, value: Double) {
        breakdown.max(by: { $0.value < $1.value }).map { (name: $0.key, value: $0.value) }
            ?? (name: "quality", value: 0.5)
    }

    /// Returns the signal with the largest difference between this asset and the keeper.
    /// When `keeperBreakdown` is provided, uses real keeper values; otherwise falls back
    /// to the signal with the lowest value as a proxy.
    private func topDeltaSignal(
        in breakdown: [String: Double],
        keeperBreakdown: [String: Double]?
    ) -> (name: String, value: Double, keeperValue: Double) {
        if let keeperBreakdown, !keeperBreakdown.isEmpty {
            // Find the shared signal key with the largest positive delta (keeperValue - candidateValue).
            var bestKey: String? = nil
            var bestDelta = -Double.infinity
            for (key, candidateValue) in breakdown {
                if let keeperValue = keeperBreakdown[key] {
                    let delta = keeperValue - candidateValue
                    if delta > bestDelta {
                        bestDelta = delta
                        bestKey = key
                    }
                }
            }
            if let key = bestKey, let candidateValue = breakdown[key], let keeperValue = keeperBreakdown[key] {
                return (name: key, value: candidateValue, keeperValue: keeperValue)
            }
        }
        // Fallback: no keeper breakdown available — use the signal with the lowest value.
        guard let entry = breakdown.min(by: { $0.value < $1.value }) else {
            return (name: "quality", value: 0.0, keeperValue: 1.0)
        }
        let approxKeeperValue = min(1.0, entry.value + 0.2)
        return (name: entry.key, value: entry.value, keeperValue: approxKeeperValue)
    }

    private func formatValue(_ value: Double) -> String {
        String(format: "%.2f", value)
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
