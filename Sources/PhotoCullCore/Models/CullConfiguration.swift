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

    public init(
        enableExactDuplicates: Bool = true,
        enableNearDuplicates: Bool = false,
        enableBurstGrouping: Bool = false,
        enableBlurDetection: Bool = false,
        nearDuplicateTimeWindowSeconds: Double = 60.0,
        burstTimeWindowSeconds: Double = 3.0,
        similarityThreshold: Double = 0.15
    ) {
        self.enableExactDuplicates = enableExactDuplicates
        self.enableNearDuplicates = enableNearDuplicates
        self.enableBurstGrouping = enableBurstGrouping
        self.enableBlurDetection = enableBlurDetection
        self.nearDuplicateTimeWindowSeconds = nearDuplicateTimeWindowSeconds
        self.burstTimeWindowSeconds = burstTimeWindowSeconds
        self.similarityThreshold = similarityThreshold
    }

    public static let `default` = CullConfiguration()
}
