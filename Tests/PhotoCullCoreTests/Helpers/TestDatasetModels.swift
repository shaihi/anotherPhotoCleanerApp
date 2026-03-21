#if canImport(CoreGraphics)
import Foundation

// MARK: - Manifest

struct DatasetManifest: Codable {
    let version: Int
    let description: String
    let categories: [DatasetCategory]
}

struct DatasetCategory: Codable {
    let id: String
    let description: String
    let groupingReason: String?
    let assets: [DatasetAsset]
    let nearDuplicatePairs: [[String]]?
    let expectedFile: String
}

struct DatasetAsset: Codable {
    let id: String
    let creationDate: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isEdited: Bool
    let burstIdentifier: String?
    let imageType: String
    let imageParams: DatasetImageParams?
    let hashSeed: String?
    let signals: DatasetSignals?
}

struct DatasetImageParams: Codable {
    let r: UInt8?
    let g: UInt8?
    let b: UInt8?
    let squareSize: Int?
}

struct DatasetSignals: Codable {
    let sharpness: Double?
    let exposure: Double?
    let subjectQuality: Double?
    let resolution: Double?
}

// MARK: - Expected outcomes

struct DatasetExpected: Codable {
    let categoryId: String
    let expectedGroups: [ExpectedGroup]
    let expectedRecommendations: [ExpectedRecommendation]
}

struct ExpectedGroup: Codable {
    let reason: String
    let memberIds: [String]
}

struct ExpectedRecommendation: Codable {
    let assetId: String
    let action: String   // "keep" or "cull"
    let minimumConfidence: Double?
    let maximumConfidence: Double?
    let mustContainReason: String?
}
#endif
