import AppKit
import SwiftUI

struct AboutView: View {
    @StateObject private var viewModel = AboutViewModel()

    private var appIcon: NSImage? {
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        if let icon = NSImage(named: NSImage.applicationIconName) {
            return icon
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            }

            Text("Macaque SVG")
                .font(.title2)
                .bold()

            Text("Version \(viewModel.currentVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 15) {
                VStack {
                    Text("✅ \(viewModel.currentSuccessCount)")
                        .font(.body)
                    Text("Builds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("❌ \(viewModel.currentFailureCount)")
                        .font(.body)
                    Text("Failures")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .foregroundStyle(.secondary)

            Text("© \(Calendar.current.component(.year, from: Date())) Vivek Krishnan")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/vksvicky/Macaque-SVG")!)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 300, height: 340)
        .onAppear {
            viewModel.loadVersionInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAboutWindow)) { _ in
            viewModel.loadVersionInfo()
        }
    }
}

#Preview {
    AboutView()
}
