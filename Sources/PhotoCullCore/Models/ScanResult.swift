import Foundation

public struct ScanResult: Sendable, Equatable {
    public let groups: [CullGroup]
    public let recommendations: [CullRecommendation]  // flat, covers all group members
    public let totalScanned: Int
    public let scanDate: Date

    public init(groups: [CullGroup], recommendations: [CullRecommendation], totalScanned: Int, scanDate: Date) {
        self.groups = groups
        self.recommendations = recommendations
        self.totalScanned = totalScanned
        self.scanDate = scanDate
    }
}
