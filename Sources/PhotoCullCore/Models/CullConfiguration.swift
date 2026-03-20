import Foundation

public struct CullConfiguration: Sendable, Equatable {
    public var enableExactDuplicates: Bool
    public var enableNearDuplicates: Bool   // Phase 2, default false
    public var enableBurstGrouping: Bool    // Phase 3, default false
    public var enableBlurDetection: Bool    // Phase 3, default false

    public init(
        enableExactDuplicates: Bool = true,
        enableNearDuplicates: Bool = false,
        enableBurstGrouping: Bool = false,
        enableBlurDetection: Bool = false
    ) {
        self.enableExactDuplicates = enableExactDuplicates
        self.enableNearDuplicates = enableNearDuplicates
        self.enableBurstGrouping = enableBurstGrouping
        self.enableBlurDetection = enableBlurDetection
    }

    public static let `default` = CullConfiguration()
}
