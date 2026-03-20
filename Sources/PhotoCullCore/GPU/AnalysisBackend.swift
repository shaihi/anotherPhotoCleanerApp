import Foundation

/// Factory that constructs the best available analysis backend.
/// When Metal is available: GPU-accelerated implementations.
/// When Metal is unavailable (CI, Simulator): CPU fallbacks.
public enum AnalysisBackend {
    /// Returns an `AnalysisBackendBundle` wired to the best available hardware.
    /// - Parameter dataLoader: Closure that returns raw image bytes for a given asset.
    public static func makeDefault(
        dataLoader: @escaping @Sendable (PhotoAsset) async throws -> Data
    ) -> AnalysisBackendBundle {
        let featureExtractor = VisionFeatureExtractor()

        if let context = MetalContext.shared {
            let sharpnessAnalyzer: any SharpnessAnalyzerProtocol =
                (try? MetalSharpnessAnalyzer(context: context)) ?? CPUSharpnessAnalyzer()
            return AnalysisBackendBundle(
                preprocessor: MetalPreprocessor(context: context, dataLoader: dataLoader),
                sharpnessAnalyzer: sharpnessAnalyzer,
                featureExtractor: featureExtractor
            )
        } else {
            return AnalysisBackendBundle(
                preprocessor: CPUPreprocessor(dataLoader: dataLoader),
                sharpnessAnalyzer: CPUSharpnessAnalyzer(),
                featureExtractor: featureExtractor
            )
        }
    }
}
