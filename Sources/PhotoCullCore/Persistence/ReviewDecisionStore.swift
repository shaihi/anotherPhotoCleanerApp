import Foundation

/// Records the user's final decision for an asset so future scans can skip it.
public enum ReviewDecision: String, Codable, Sendable {
    /// User confirmed this photo should be kept; do not surface it again.
    case kept
    /// User confirmed deletion; the asset has been moved to Trash.
    case deleted
}

/// Persists review decisions across scan sessions.
public protocol ReviewDecisionStore: Sendable {
    func record(assetId: String, decision: ReviewDecision) async
    func decision(for assetId: String) async -> ReviewDecision?
    func decisions(for assetIds: [String]) async -> [String: ReviewDecision]
}

// MARK: - In-memory implementation (tests and mock sessions)

public actor InMemoryReviewDecisionStore: ReviewDecisionStore {
    private var store: [String: ReviewDecision] = [:]

    public init() {}

    public func record(assetId: String, decision: ReviewDecision) {
        store[assetId] = decision
    }

    public func decision(for assetId: String) -> ReviewDecision? {
        store[assetId]
    }

    public func decisions(for assetIds: [String]) -> [String: ReviewDecision] {
        var result: [String: ReviewDecision] = [:]
        for id in assetIds {
            if let d = store[id] { result[id] = d }
        }
        return result
    }
}
