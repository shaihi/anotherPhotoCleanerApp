import Foundation

/// CPU-only prefilter that nominates asset pairs for near-duplicate / burst comparison
/// using only metadata (no image decoding).
public struct MetadataPrefilter: Sendable {

    /// Maximum group size for the time-proximity sliding window.
    /// Guards against O(n²) pair explosion for bursts or rapid-fire shooting sessions.
    private static let maxClusterSize = 20

    public init() {}

    /// Returns candidate pairs drawn from two passes:
    /// 1. Burst pairs — assets that share a non-nil `burstIdentifier`.
    /// 2. Time-proximity pairs — remaining assets whose `creationDate` falls within
    ///    `configuration.nearDuplicateTimeWindowSeconds` of each other.
    ///
    /// Pairs are filtered to remove:
    /// - Cross-media-type combinations (e.g. photo vs video).
    /// - Pairs whose aspect ratios differ by more than 5%.
    public func candidates(
        from assets: [PhotoAsset],
        configuration: CullConfiguration
    ) -> [CandidatePair] {
        guard assets.count >= 2 else { return [] }

        var pairs: [CandidatePair] = []
        var assetIdsInBurstPairs: Set<String> = []

        // MARK: Pass 1 — burst pairs
        let burstGroups = Dictionary(grouping: assets.filter { $0.burstIdentifier != nil },
                                     by: { $0.burstIdentifier! })
        for (_, members) in burstGroups where members.count >= 2 {
            let burstPairs = allPairs(within: members, reason: .burstId)
            let filtered = burstPairs.filter { isCompatible($0, assets: assets) }
            pairs.append(contentsOf: filtered)
            for pair in filtered {
                assetIdsInBurstPairs.insert(pair.assetIdA)
                assetIdsInBurstPairs.insert(pair.assetIdB)
            }
        }

        // MARK: Pass 2 — time-proximity pairs on remaining assets
        let remaining = assets.filter { !assetIdsInBurstPairs.contains($0.id) }
        let timed = remaining.filter { $0.creationDate != nil }
            .sorted { $0.creationDate! < $1.creationDate! }

        let windowSeconds = configuration.nearDuplicateTimeWindowSeconds
        var windowStart = 0
        for i in 0 ..< timed.count {
            let anchor = timed[i].creationDate!
            // Advance window start past any assets no longer within range of anchor
            while timed[i].creationDate!.timeIntervalSince(timed[windowStart].creationDate!) > windowSeconds {
                windowStart += 1
            }
            // Cap how far ahead this anchor can look: each anchor `i` examines at most
            // `maxClusterSize` assets beyond itself, keeping per-anchor pair count bounded.
            let windowEnd = min(i + Self.maxClusterSize, timed.count - 1)
            let jStart = i + 1
            guard jStart <= windowEnd else { continue }
            for j in jStart ... windowEnd {
                let other = timed[j]
                guard other.creationDate!.timeIntervalSince(anchor) <= windowSeconds else { break }
                let pair = CandidatePair(
                    assetIdA: timed[i].id,
                    assetIdB: other.id,
                    prefilterReason: .timeProximity
                )
                if isCompatible(pair, assets: assets) {
                    pairs.append(pair)
                }
            }
        }

        return pairs
    }

    // MARK: - Private helpers

    /// Generates all unique pairs within a collection for a given reason.
    private func allPairs(within assets: [PhotoAsset], reason: PrefilterReason) -> [CandidatePair] {
        var result: [CandidatePair] = []
        for i in 0 ..< assets.count {
            for j in (i + 1) ..< assets.count {
                result.append(CandidatePair(
                    assetIdA: assets[i].id,
                    assetIdB: assets[j].id,
                    prefilterReason: reason
                ))
            }
        }
        return result
    }

    /// Returns `true` if the pair passes the cross-media-type and aspect-ratio filters.
    private func isCompatible(_ pair: CandidatePair, assets: [PhotoAsset]) -> Bool {
        guard let a = assets.first(where: { $0.id == pair.assetIdA }),
              let b = assets.first(where: { $0.id == pair.assetIdB }) else {
            return false
        }
        // Reject cross-media-type pairs (e.g. photo vs video).
        guard a.mediaType == b.mediaType else { return false }

        // Reject pairs whose aspect ratios differ by more than 5%.
        // Skip the check if either asset has zero dimensions (metadata unavailable).
        if a.pixelWidth > 0 && a.pixelHeight > 0 && b.pixelWidth > 0 && b.pixelHeight > 0 {
            let ratioA = Double(a.pixelWidth) / Double(a.pixelHeight)
            let ratioB = Double(b.pixelWidth) / Double(b.pixelHeight)
            let maxRatio = max(ratioA, ratioB)
            let minRatio = min(ratioA, ratioB)
            let relativeDiff = (maxRatio - minRatio) / maxRatio
            if relativeDiff > 0.05 { return false }
        }

        return true
    }
}
