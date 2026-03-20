#if canImport(Metal)
import Metal
import Foundation

/// GPU sharpness analyzer using an embedded Metal Laplacian kernel.
/// Scores are normalized identically to CPUSharpnessAnalyzer.
/// The MTLLibrary and MTLComputePipelineState are compiled once at init time.
public struct MetalSharpnessAnalyzer: SharpnessAnalyzerProtocol {
    private let context: MetalContext
    private let pipelineState: MTLComputePipelineState

    public init(context: MetalContext) throws {
        self.context = context
        let library = try context.makeLibrary(source: Self.laplacianMSL)
        guard let fn = library.makeFunction(name: "laplacianKernel") else {
            throw MetalSharpnessError.missingKernelFunction
        }
        self.pipelineState = try context.device.makeComputePipelineState(function: fn)
    }

    public func analyzeSharpness(of image: ProcessedImage) async throws -> SharpnessScore {
        guard let pb = image.pixelBuffer else {
            throw ProcessedImageError.missingPixelBuffer(assetId: image.assetId)
        }

        // Upload pixel buffer to Metal texture
        let device = context.device
        let w = pb.width, h = pb.height, bpr = pb.bytesPerRow

        let inputDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        inputDesc.usage = [.shaderRead]
        guard let inputTexture = device.makeTexture(descriptor: inputDesc) else {
            return try await CPUSharpnessAnalyzer().analyzeSharpness(of: image)
        }
        pb.data.withUnsafeBytes { rawPtr in
            inputTexture.replace(region: MTLRegionMake2D(0, 0, w, h),
                                 mipmapLevel: 0,
                                 withBytes: rawPtr.baseAddress!,
                                 bytesPerRow: bpr)
        }

        // Output texture: single-channel float (Laplacian response)
        let outputDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float, width: w, height: h, mipmapped: false)
        outputDesc.usage = [.shaderRead, .shaderWrite]
        guard let outputTexture = device.makeTexture(descriptor: outputDesc) else {
            return try await CPUSharpnessAnalyzer().analyzeSharpness(of: image)
        }

        guard let commandBuffer = context.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return try await CPUSharpnessAnalyzer().analyzeSharpness(of: image)
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width:  (w + 15) / 16,
            height: (h + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commandBuffer.addCompletedHandler { buffer in
                if let error = buffer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            commandBuffer.commit()
        }

        // Read back float values and compute variance on CPU
        var floatPixels = [Float](repeating: 0, count: w * h)
        floatPixels.withUnsafeMutableBytes { ptr in
            outputTexture.getBytes(ptr.baseAddress!, bytesPerRow: w * 4,
                                   from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        }

        let count = Float(w * h)
        let mean = floatPixels.reduce(0, +) / count
        let variance = floatPixels.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / count

        // Metal textures sample RGB as [0,1]; CPU computes in [0,255] space.
        // Scale variance to match CPU luminance range (multiply by 255²).
        let scaledVariance = Double(variance) * (255.0 * 255.0)
        let score = SharpnessNormalization.normalize(variance: scaledVariance)
        return SharpnessScore(value: score)
    }

    // MSL Laplacian kernel embedded as a string — avoids SPM .metal resource issues.
    private static let laplacianMSL = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void laplacianKernel(
        texture2d<float, access::read>  inTex  [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        uint2 gid [[thread_position_in_grid]])
    {
        uint w = inTex.get_width();
        uint h = inTex.get_height();
        if (gid.x >= w || gid.y >= h) return;

        uint2 top    = uint2(gid.x, gid.y > 0     ? gid.y - 1 : 0);
        uint2 bottom = uint2(gid.x, gid.y < h - 1 ? gid.y + 1 : h - 1);
        uint2 left   = uint2(gid.x > 0     ? gid.x - 1 : 0,     gid.y);
        uint2 right  = uint2(gid.x < w - 1 ? gid.x + 1 : w - 1, gid.y);

        float3 weights = float3(0.299, 0.587, 0.114);
        float c  = dot(inTex.read(gid   ).rgb, weights);
        float t  = dot(inTex.read(top   ).rgb, weights);
        float bo = dot(inTex.read(bottom).rgb, weights);
        float l  = dot(inTex.read(left  ).rgb, weights);
        float r  = dot(inTex.read(right ).rgb, weights);

        float lap = t + bo + l + r - 4.0 * c;
        outTex.write(float4(lap, 0, 0, 1), gid);
    }
    """
}

public enum MetalSharpnessError: Error, Sendable {
    case missingKernelFunction
}

#else
/// Stub when Metal is not available — delegates to CPUSharpnessAnalyzer.
public struct MetalSharpnessAnalyzer: SharpnessAnalyzerProtocol {
    public init(context: MetalContext) throws {}
    public func analyzeSharpness(of image: ProcessedImage) async throws -> SharpnessScore {
        try await CPUSharpnessAnalyzer().analyzeSharpness(of: image)
    }
}
#endif
