import Foundation

public struct CullConfiguration: Sendable, Equatable {
    public var enableExactDuplicates: Bool
    public var enableNearDuplicates: Bool   // Phase 2, default false
    public var enableBurstGrouping: Bool    // Phase 3, default false
    public var enableBlurDetection: Bool    // Phase 5, default false

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

    // MARK: - Phase 4 ranking parameters

    /// Minimum confidence required to emit a `.cull` recommendation; lower → `.keep`.
    public var confidenceThreshold: Double = 0.60
    /// Composite score proximity band for the within-tier date tiebreaker.
    /// When two assets' scores differ by less than this value they are treated as
    /// effectively equal and the earlier creation date wins (first shot of a burst
    /// is preferred). Set to 0.0 to disable and always use exact score ordering.
    public var scoreBandWidth: Double = 0.02
    /// Weight for the sharpness signal in the composite score.
    public var sharpnessWeight: Double = 0.40
    /// Weight for the exposure signal in the composite score.
    public var exposureWeight: Double = 0.25
    /// Weight for the subject-quality signal in the composite score.
    public var subjectWeight: Double = 0.25
    /// Weight for the resolution signal in the composite score.
    public var resolutionWeight: Double = 0.10

    // MARK: - Phase 5 blur detection parameters

    /// Absolute sharpness threshold below which a photo may be classified as accidentally blurry.
    /// Corresponds to a Laplacian-variance normalized score; values below ~0.10 represent
    /// near-uniform images consistent with camera shake or missed focus.
    /// Only evaluated when `enableBlurDetection` is true.
    public var accidentalBlurThreshold: Double = 0.10
    /// Relative factor: candidate must have sharpness < keeperSharpness × factor to meet
    /// the relative condition for accidental blur. Both absolute and relative conditions
    /// must be true for a `.accidental` classification.
    public var blurRelativeFactor: Double = 0.50
    /// Minimum sharpness the keeper must have for a within-group blur comparison to be
    /// meaningful. If the keeper's sharpness is below this value, Rule C emits `.unclear`
    /// regardless of the candidate's score.
    public var blurKeeperSharpnessMinimum: Double = 0.50

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
