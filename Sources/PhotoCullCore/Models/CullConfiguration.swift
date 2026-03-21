import Foundation

public struct CullConfiguration: Sendable, Equatable {
    public var enableExactDuplicates: Bool
    public var enableNearDuplicates: Bool   // Phase 2, default false
    public var enableBurstGrouping: Bool    // Phase 3, default false
    public var enableBlurDetection: Bool    // Phase 3, default false

    // MARK: - Phase 3 similarity parameters

    /// Sliding-window width (seconds) for time-proximity candidate pairing.
    public var nearDuplicateTimeWindowSeconds: Double
    /// Time window (seconds) for burst detection (informational, not used in MetadataPrefilter).
    public var burstTimeWindowSeconds: Double
    /// Cosine-distance threshold; pairs below this threshold are confirmed as near-duplicates.
    public var similarityThreshold: Double
    /// Maximum number of members taken from a single burst group before generating pairs.
    /// Caps the pair count at C(maxBurstGroupSize, 2) to avoid O(n²) explosion for
    /// very long bursts (e.g. 50 members → 1,225 pairs without this cap).
    /// Members are selected by ascending `creationDate` when truncation is needed.
    public var maxBurstGroupSize: Int

    public init(
        enableExactDuplicates: Bool = true,
        enableNearDuplicates: Bool = false,
        enableBurstGrouping: Bool = false,
        enableBlurDetection: Bool = false,
        nearDuplicateTimeWindowSeconds: Double = 60.0,
        burstTimeWindowSeconds: Double = 3.0,
        similarityThreshold: Double = 0.15,
        maxBurstGroupSize: Int = 30
    ) {
        self.enableExactDuplicates = enableExactDuplicates
        self.enableNearDuplicates = enableNearDuplicates
        self.enableBurstGrouping = enableBurstGrouping
        self.enableBlurDetection = enableBlurDetection
        self.nearDuplicateTimeWindowSeconds = nearDuplicateTimeWindowSeconds
        self.burstTimeWindowSeconds = burstTimeWindowSeconds
        self.similarityThreshold = similarityThreshold
        self.maxBurstGroupSize = maxBurstGroupSize
    }

    public static let `default` = CullConfiguration()
}
