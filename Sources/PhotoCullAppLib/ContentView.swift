import SwiftUI

struct ContentView: View {
    @State private var viewModel = ScanViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.statusText)
                .multilineTextAlignment(.center)
                .padding()

            Button(viewModel.isScanning ? "Scanning…" : "Scan") {
                viewModel.startScan()
            }
            .disabled(viewModel.isScanning)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 200)
    }
}
