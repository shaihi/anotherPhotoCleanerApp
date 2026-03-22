import Foundation
import PhotoCullCore

/// Persists review decisions in UserDefaults so they survive app restarts.
///
/// Storage format: `[String: String]` dictionary under `UserDefaults` key
/// `"photocull.review_decisions"`, where keys are asset IDs and values are
/// `ReviewDecision.rawValue` strings ("kept" or "deleted").
public actor UserDefaultsReviewDecisionStore: ReviewDecisionStore {
    private static let defaultsKey = "photocull.review_decisions"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func record(assetId: String, decision: ReviewDecision) {
        var map = loadMap()
        map[assetId] = decision.rawValue
        saveMap(map)
    }

    public func decision(for assetId: String) -> ReviewDecision? {
        let map = loadMap()
        guard let raw = map[assetId] else { return nil }
        return ReviewDecision(rawValue: raw)
    }

    public func decisions(for assetIds: [String]) -> [String: ReviewDecision] {
        let map = loadMap()
        var result: [String: ReviewDecision] = [:]
        for id in assetIds {
            if let raw = map[id], let d = ReviewDecision(rawValue: raw) {
                result[id] = d
            }
        }
        return result
    }

    // MARK: - Private

    private func loadMap() -> [String: String] {
        defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    private func saveMap(_ map: [String: String]) {
        defaults.set(map, forKey: Self.defaultsKey)
    }
}
