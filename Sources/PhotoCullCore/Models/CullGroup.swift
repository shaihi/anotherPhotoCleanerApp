import Foundation

public enum GroupingReason: Sendable, Equatable {
    case exactDuplicate
    case nearDuplicate   // Phase 2
    case burst           // Phase 3
}

public enum CullGroupError: Error, Sendable {
    case insufficientMembers(count: Int)
}

public struct CullGroup: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let reason: GroupingReason
    public let members: [PhotoAsset]   // ordered, best-first after ranking

    public init(id: UUID = UUID(), reason: GroupingReason, members: [PhotoAsset]) throws {
        guard members.count >= 2 else {
            throw CullGroupError.insufficientMembers(count: members.count)
        }
        self.id = id
        self.reason = reason
        self.members = members
    }
}
