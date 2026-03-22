import Foundation
import AppKit
import PhotoCullCore

enum DeleteState: Equatable {
    case idle
    case confirming
    case deleting
    case done(Int)
    case failed(String)
}

@MainActor
@Observable
final class ReviewViewModel {
    private let result: ScanResult
    private let thumbnailProvider: ThumbnailProvider
    private let service: (any PhotoLibraryServiceProtocol)?
    private let decisionStore: (any ReviewDecisionStore)?
    private var overrides: [String: CullAction] = [:]
    private var thumbnailCache: [String: NSImage] = [:]
    private var deletedAssetIds: Set<String> = []

    private(set) var blockedMessage: String? = nil
    private(set) var deleteState: DeleteState = .idle

    init(
        result: ScanResult,
        thumbnailProvider: ThumbnailProvider = NullThumbnailProvider(),
        service: (any PhotoLibraryServiceProtocol)? = nil,
        decisionStore: (any ReviewDecisionStore)? = nil
    ) {
        self.result = result
        self.thumbnailProvider = thumbnailProvider
        self.service = service
        self.decisionStore = decisionStore
    }

    // MARK: - Data access

    var groups: [CullGroup] {
        result.groups.compactMap { group in
            let remaining = group.members.filter { !deletedAssetIds.contains($0.id) }
            guard remaining.count > 1 else { return nil }
            return try? CullGroup(reason: group.reason, members: remaining)
        }
    }

    var keepCount: Int {
        result.recommendations.filter {
            !deletedAssetIds.contains($0.asset.id) && effectiveAction(for: $0.asset.id) == .keep
        }.count
    }

    var cullCount: Int {
        result.recommendations.filter {
            !deletedAssetIds.contains($0.asset.id) && effectiveAction(for: $0.asset.id) == .cull
        }.count
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

    func qualityScore(for assetId: String) -> Double? {
        recommendation(for: assetId)?.qualityScore
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

    // MARK: - Delete flow

    func requestDelete() {
        guard cullCount > 0 else { return }
        deleteState = .confirming
    }

    func cancelDelete() {
        deleteState = .idle
    }

    func confirmDelete() async {
        let idsToDelete = result.recommendations
            .filter { effectiveAction(for: $0.asset.id) == .cull }
            .map { $0.asset.id }
        guard !idsToDelete.isEmpty else {
            deleteState = .idle
            return
        }
        deleteState = .deleting
        do {
            try await service?.deleteAssets(ids: idsToDelete)

            // Record decisions so future scans skip these assets.
            if let store = decisionStore {
                for id in idsToDelete {
                    await store.record(assetId: id, decision: .deleted)
                }
                // Also record kept assets in the same groups so they are
                // remembered as reviewed (prevents re-pairing with new arrivals
                // from resurfacing the group unnecessarily).
                let deletedSet = Set(idsToDelete)
                let affectedGroupMembers = result.groups
                    .filter { group in group.members.contains { deletedSet.contains($0.id) } }
                    .flatMap { $0.members.map(\.id) }
                for id in affectedGroupMembers where !deletedSet.contains(id) {
                    await store.record(assetId: id, decision: .kept)
                }
            }

            // Remove deleted rows from the UI immediately.
            deletedAssetIds.formUnion(idsToDelete)
            deleteState = .done(idsToDelete.count)
            try? await Task.sleep(for: .seconds(2))
            deleteState = .idle
        } catch {
            deleteState = .failed(error.localizedDescription)
        }
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
