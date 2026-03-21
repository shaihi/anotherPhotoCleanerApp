import Foundation

/// Clusters confirmed similar pairs into `CullGroup`s using Union-Find.
public struct SimilarityGroupBuilder: Sendable {
    public init() {}

    /// Builds `CullGroup`s from the confirmed pairs.
    ///
    /// - Parameters:
    ///   - confirmedPairs: Pairs with `similarityScore` set, already below threshold.
    ///   - assets: Lookup map of `assetId` → `PhotoAsset` for all assets.
    /// - Returns: One `CullGroup` per connected component of size ≥ 2.
    ///   Each group's `reason` is `.burst` when every member shares the same
    ///   non-nil `burstIdentifier`, otherwise `.nearDuplicate`.
    public func buildGroups(
        from confirmedPairs: [CandidatePair],
        assets: [String: PhotoAsset]
    ) -> [CullGroup] {
        guard !confirmedPairs.isEmpty else { return [] }

        // Union all confirmed pairs.
        var uf = UnionFind<String>()
        for pair in confirmedPairs {
            uf.union(pair.assetIdA, pair.assetIdB)
        }

        // Filter to components with at least 2 members.
        let components = uf.components().filter { $0.count >= 2 }

        return components.compactMap { component in
            // Map IDs to assets; skip IDs not found in the lookup.
            let members = component.compactMap { assets[$0] }
            guard members.count >= 2 else { return nil }

            let reason = groupingReason(for: members)
            return try? CullGroup(reason: reason, members: members)
        }
    }

    // MARK: - Private helpers

    /// Returns `.burst` if all members share the same non-nil `burstIdentifier`,
    /// otherwise `.nearDuplicate`.
    private func groupingReason(for members: [PhotoAsset]) -> GroupingReason {
        guard let burstId = members.first?.burstIdentifier else {
            return .nearDuplicate
        }
        let allShareBurst = members.allSatisfy { $0.burstIdentifier == burstId }
        return allShareBurst ? .burst : .nearDuplicate
    }
}
