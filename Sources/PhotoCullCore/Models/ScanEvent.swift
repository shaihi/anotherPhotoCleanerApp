import Foundation

public enum ScanEvent: Sendable {
    case progress(ScanProgress)
    case completed(ScanResult)
}
