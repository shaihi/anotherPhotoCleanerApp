import Foundation

public struct GroupBuilder: Sendable {
    public init() {}

    /// Groups HashResults by cryptoHash. Only groups with 2+ members are returned.
    public func buildGroups(from results: [HashResult]) -> [CullGroup] {
        var grouped: [Data: [PhotoAsset]] = [:]
        for result in results {
            grouped[result.cryptoHash, default: []].append(result.asset)
        }
        return grouped.values
            .filter { $0.count >= 2 }
            .compactMap { assets in try? CullGroup(reason: .exactDuplicate, members: assets) }
            .sorted { $0.members.count > $1.members.count }
    }
}
