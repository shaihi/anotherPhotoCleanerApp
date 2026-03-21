import SwiftUI

struct SignalBreakdownView: View {
    let breakdown: [String: Double]

    private static let orderedKeys: [String] = ["sharpness", "exposure", "subjectQuality", "resolution"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Self.orderedKeys.filter { breakdown[$0] != nil }, id: \.self) { key in
                if let value = breakdown[key] {
                    HStack(spacing: 6) {
                        Text(displayName(for: key))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .trailing)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.08))
                                    .cornerRadius(2)
                                Rectangle()
                                    .fill(barColor(for: value))
                                    .frame(width: geo.size.width * value)
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 6)
                        Text(String(format: "%.0f%%", value * 100))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func displayName(for key: String) -> String {
        switch key {
        case "sharpness":     return "Sharp"
        case "exposure":      return "Exposure"
        case "subjectQuality": return "Subject"
        case "resolution":    return "Resolution"
        default:              return key
        }
    }

    private func barColor(for value: Double) -> Color {
        if value >= 0.7 { return .green }
        if value >= 0.4 { return .yellow }
        return .orange
    }
}
