#if canImport(CoreGraphics)
import Foundation
@testable import PhotoCullCore

enum TestDatasetLoader {

    // MARK: - Decode

    static func loadManifest() throws -> DatasetManifest {
        guard let url = Bundle.module.url(forResource: "TestDataset/manifest", withExtension: "json") else {
            throw LoaderError.resourceNotFound("TestDataset/manifest.json — ensure Package.swift includes resources: [.copy(\"TestDataset\")]")
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(DatasetManifest.self, from: data)
    }

    static func loadCategory(_ id: String) throws -> DatasetCategory {
        let manifest = try loadManifest()
        guard let category = manifest.categories.first(where: { $0.id == id }) else {
            throw LoaderError.categoryNotFound(id)
        }
        return category
    }

    static func loadExpected(for category: DatasetCategory) throws -> DatasetExpected {
        // expectedFile is a relative path like "expected/exact-duplicates.json"
        let resourcePath = "TestDataset/" + category.expectedFile
        // Strip extension for Bundle.module lookup
        let withoutExtension = resourcePath.hasSuffix(".json") ? String(resourcePath.dropLast(5)) : resourcePath
        guard let url = Bundle.module.url(forResource: withoutExtension, withExtension: "json") else {
            throw LoaderError.resourceNotFound(resourcePath)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DatasetExpected.self, from: data)
    }

    // MARK: - Synthesize

    static func synthesize(category: DatasetCategory) -> (assets: [PhotoAsset], imageDataMap: [String: Data]) {
        var assets: [PhotoAsset] = []
        var imageDataMap: [String: Data] = [:]
        let isoFormatter = ISO8601DateFormatter()
        for da in category.assets {
            let date = da.creationDate.flatMap { isoFormatter.date(from: $0) }
            let asset = PhotoAsset(
                id: da.id,
                creationDate: date,
                pixelWidth: da.pixelWidth,
                pixelHeight: da.pixelHeight,
                isFavorite: da.isFavorite,
                isEdited: da.isEdited,
                burstIdentifier: da.burstIdentifier,
                mediaSubtypes: [],
                mediaType: .image
            )
            assets.append(asset)
            imageDataMap[da.id] = imageData(for: da)
        }
        return (assets, imageDataMap)
    }

    static func synthesizeWithSignals(category: DatasetCategory) -> (
        assets: [PhotoAsset],
        imageDataMap: [String: Data],
        signals: [String: [SignalValue]]
    ) {
        let (assets, imageDataMap) = synthesize(category: category)
        var signalMap: [String: [SignalValue]] = [:]
        for da in category.assets {
            guard let ds = da.signals else {
                signalMap[da.id] = []
                continue
            }
            var values: [SignalValue] = []
            if let v = ds.sharpness      { values.append(SignalValue(signal: .sharpness, value: v)) }
            if let v = ds.exposure       { values.append(SignalValue(signal: .exposure, value: v)) }
            if let v = ds.subjectQuality { values.append(SignalValue(signal: .subjectQuality, value: v)) }
            if let v = ds.resolution     { values.append(SignalValue(signal: .resolution, value: v)) }
            signalMap[da.id] = values
        }
        return (assets, imageDataMap, signalMap)
    }

    static func mockService(for categoryId: String) throws -> MockPhotoLibraryService {
        let category = try loadCategory(categoryId)
        let (assets, imageDataMap) = synthesize(category: category)
        return MockPhotoLibraryService(assets: assets, imageDataMap: imageDataMap)
    }

    /// Returns HashResult for each asset, sorted by asset.id ascending.
    /// Assets sharing the same hashSeed produce identical cryptoHash values.
    /// Assets with nil hashSeed get a hash derived from their own id.
    /// Callers that index the result must document this sort-order assumption.
    static func hashResults(for category: DatasetCategory) -> [HashResult] {
        let sorted = category.assets.sorted { $0.id < $1.id }
        let isoFormatter = ISO8601DateFormatter()
        return sorted.map { da in
            let seed = da.hashSeed ?? da.id
            let hashData = Data(seed.utf8)
            let date = da.creationDate.flatMap { isoFormatter.date(from: $0) }
            let asset = PhotoAsset(
                id: da.id,
                creationDate: date,
                pixelWidth: da.pixelWidth,
                pixelHeight: da.pixelHeight,
                isFavorite: da.isFavorite,
                isEdited: da.isEdited,
                burstIdentifier: da.burstIdentifier,
                mediaSubtypes: [],
                mediaType: .image
            )
            return HashResult(asset: asset, cryptoHash: hashData)
        }
    }

    // MARK: - Errors

    enum LoaderError: Error, LocalizedError {
        case resourceNotFound(String)
        case categoryNotFound(String)

        var errorDescription: String? {
            switch self {
            case .resourceNotFound(let path): return "TestDatasetLoader: resource not found — \(path)"
            case .categoryNotFound(let id):   return "TestDatasetLoader: category '\(id)' not in manifest"
            }
        }
    }

    // MARK: - Private helpers

    private static func imageData(for asset: DatasetAsset) -> Data {
        let p = asset.imageParams
        switch asset.imageType {
        case "checkerboard":
            return TestImageFactory.checkerboard(
                width: asset.pixelWidth,
                height: asset.pixelHeight,
                squareSize: p?.squareSize ?? 4
            )
        case "gradient":
            return TestImageFactory.gradient(
                width: asset.pixelWidth,
                height: asset.pixelHeight
            )
        default: // "solid" and anything unknown
            return TestImageFactory.solidColor(
                width: asset.pixelWidth,
                height: asset.pixelHeight,
                r: p?.r ?? 128,
                g: p?.g ?? 128,
                b: p?.b ?? 128
            )
        }
    }
}
#endif
