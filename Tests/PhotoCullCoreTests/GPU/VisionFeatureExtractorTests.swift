#if canImport(Vision)
import XCTest
@testable import PhotoCullCore

final class VisionFeatureExtractorTests: XCTestCase {
    let extractor = VisionFeatureExtractor()

    func makeImage(from pixelBuffer: PixelBuffer, id: String = "img") -> ProcessedImage {
        ProcessedImage(assetId: id, width: pixelBuffer.width, height: pixelBuffer.height, pixelBuffer: pixelBuffer)
    }

    func testNonEmptyFeatureVector() async throws {
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64)
        let img = makeImage(from: pb)
        let vector = try await extractor.extractFeatures(from: img)
        XCTAssertFalse(vector.values.isEmpty)
    }

    func testIdenticalImagesProduceSameVector() async throws {
        let pb = TestImageFactory.solidColorPixelBuffer()
        let imgA = makeImage(from: pb, id: "a")
        let imgB = makeImage(from: pb, id: "b")
        let vecA = try await extractor.extractFeatures(from: imgA)
        let vecB = try await extractor.extractFeatures(from: imgB)
        XCTAssertEqual(vecA.values, vecB.values)
    }

    func testDifferentImagesProduceDifferentVectors() async throws {
        let pb1 = TestImageFactory.solidColorPixelBuffer(r: 255, g: 0, b: 0)
        let pb2 = TestImageFactory.checkerboardPixelBuffer()
        let vecA = try await extractor.extractFeatures(from: makeImage(from: pb1, id: "a"))
        let vecB = try await extractor.extractFeatures(from: makeImage(from: pb2, id: "b"))
        let different = zip(vecA.values, vecB.values).contains { abs($0 - $1) > 0.001 }
        XCTAssertTrue(different, "Distinct images should produce different feature vectors")
    }

    func testMissingPixelBufferThrows() async throws {
        let img = ProcessedImage(assetId: "x", width: 64, height: 64)
        do {
            _ = try await extractor.extractFeatures(from: img)
            XCTFail("Expected throw")
        } catch ProcessedImageError.missingPixelBuffer { /* expected */ }
    }
}
#endif
