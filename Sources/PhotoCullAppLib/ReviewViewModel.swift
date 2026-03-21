import Foundation
import AppKit
import PhotoCullCore

@MainActor
@Observable
final class ReviewViewModel {
    private let result: ScanResult
    private let thumbnailProvider: ThumbnailProvider
    private var overrides: [String: CullAction] = [:]
    private var thumbnailCache: [String: NSImage] = [:]

    private(set) var blockedMessage: String? = nil

    init(result: ScanResult, thumbnailProvider: ThumbnailProvider = NullThumbnailProvider()) {
        self.result = result
        self.thumbnailProvider = thumbnailProvider
    }

    // MARK: - Data access

    var groups: [CullGroup] {
        result.groups
    }

    var keepCount: Int {
        result.recommendations.filter { effectiveAction(for: $0.asset.id) == .keep }.count
    }

    var cullCount: Int {
        result.recommendations.filter { effectiveAction(for: $0.asset.id) == .cull }.count
    }

    func recommendation(for assetId: String) -> CullRecommendation? {
        result.recommendations.first { $0.asset.id == assetId }
    }

    func effectiveAction(for assetId: String) -> CullAction {
        overrides[assetId] ?? recommendation(for: assetId)?.action ?? .keep
    }

    func isOverridden(for assetId: String) -> Bool {
        overrides[assetId] != nil
    }

    func signalBreakdown(for assetId: String) -> [String: Double]? {
        recommendation(for: assetId)?.signalBreakdown
    }

    // MARK: - Overrides

    /// Attempts to apply an override. Returns `false` and sets `blockedMessage`
    /// if the safety rule (≥1 keeper per group) would be violated.
    @discardableResult
    func overrideAction(assetId: String, to action: CullAction) -> Bool {
        if action == .cull, let group = group(containing: assetId) {
            let keeperCount = group.members.filter { effectiveAction(for: $0.id) == .keep }.count
            if effectiveAction(for: assetId) == .keep && keeperCount <= 1 {
                blockedMessage = "At least one photo must be kept in each group."
                return false
            }
        }
        blockedMessage = nil
        overrides[assetId] = action
        return true
    }

    func resetOverride(for assetId: String) {
        overrides.removeValue(forKey: assetId)
        blockedMessage = nil
    }

    func clearBlockedMessage() {
        blockedMessage = nil
    }

    // MARK: - Thumbnails

    func hasThumbnail(for assetId: String) -> Bool {
        thumbnailCache[assetId] != nil
    }

    func cachedThumbnail(for assetId: String) -> NSImage? {
        thumbnailCache[assetId]
    }

    func loadThumbnail(for assetId: String) async {
        guard thumbnailCache[assetId] == nil else { return }
        if let image = await thumbnailProvider.thumbnail(for: assetId) {
            thumbnailCache[assetId] = image
        }
    }

    // MARK: - Private helpers

    private func group(containing assetId: String) -> CullGroup? {
        result.groups.first { group in
            group.members.contains { $0.id == assetId }
        }
    }
}
