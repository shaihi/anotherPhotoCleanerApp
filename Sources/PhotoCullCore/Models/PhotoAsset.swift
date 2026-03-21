import Foundation

/// Mirrors PHAssetMediaType without importing Photos framework in core library.
public enum MediaType: String, Sendable, Equatable, Hashable {
    case image
    case video
    case audio
    case unknown
}

public struct PhotoAsset: Sendable, Identifiable, Equatable, Hashable {
    public let id: String          // PHAsset.localIdentifier
    public let creationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let isFavorite: Bool
    public let isEdited: Bool
    public let burstIdentifier: String?
    public let mediaSubtypes: Set<String>
    public let mediaType: MediaType

    public init(
        id: String,
        creationDate: Date? = nil,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        isFavorite: Bool = false,
        isEdited: Bool = false,
        burstIdentifier: String? = nil,
        mediaSubtypes: Set<String> = [],
        mediaType: MediaType = .image
    ) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isFavorite = isFavorite
        self.isEdited = isEdited
        self.burstIdentifier = burstIdentifier
        self.mediaSubtypes = mediaSubtypes
        self.mediaType = mediaType
    }
}
