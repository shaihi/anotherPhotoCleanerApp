#if canImport(Metal)
import Metal
import Foundation

/// Wraps a Metal device and command queue.
/// `shared` is nil when no Metal-capable GPU is available (CI, Simulator without Metal).
/// Both MTLDevice and MTLCommandQueue are thread-safe per Apple documentation.
public final class MetalContext: @unchecked Sendable {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    private init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
    }

    public static let shared: MetalContext? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        return MetalContext(device: device, commandQueue: queue)
    }()

    /// Compiles a Metal library from MSL source code at runtime.
    /// Used to avoid SPM resource bundle complexity for .metal files.
    public func makeLibrary(source: String) throws -> MTLLibrary {
        try device.makeLibrary(source: source, options: nil)
    }
}
#else
/// Stub for platforms or CI environments without Metal support.
public final class MetalContext: @unchecked Sendable {
    public static let shared: MetalContext? = nil
}
#endif
