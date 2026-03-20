#if canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

final class AnalysisBackendTests: XCTestCase {
    let dummyLoader: @Sendable (PhotoAsset) async throws -> Data = { _ in Data() }

    func testMakeDefaultReturnsBundleNotTuple() {
        let bundle = AnalysisBackend.makeDefault(dataLoader: dummyLoader)
        // If this compiles and runs, the return type is AnalysisBackendBundle (not a tuple)
        XCTAssertNotNil(bundle.preprocessor)
        XCTAssertNotNil(bundle.sharpnessAnalyzer)
        XCTAssertNotNil(bundle.featureExtractor)
    }

    func testBundleContainsGPUImplsWhenMetalAvailable() throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let bundle = AnalysisBackend.makeDefault(dataLoader: dummyLoader)
        XCTAssertTrue(bundle.preprocessor is MetalPreprocessor)
        XCTAssertTrue(bundle.sharpnessAnalyzer is MetalSharpnessAnalyzer)
    }

    func testBundleContainsCPUImplsWhenNoMetal() throws {
        try XCTSkipUnless(MetalContext.shared == nil, "Metal available — this test requires no GPU")
        let bundle = AnalysisBackend.makeDefault(dataLoader: dummyLoader)
        XCTAssertTrue(bundle.preprocessor is CPUPreprocessor)
        XCTAssertTrue(bundle.sharpnessAnalyzer is CPUSharpnessAnalyzer)
    }

    func testVisionExtractorAlwaysPresent() {
        let bundle = AnalysisBackend.makeDefault(dataLoader: dummyLoader)
        XCTAssertTrue(bundle.featureExtractor is VisionFeatureExtractor)
    }
}
#endif
