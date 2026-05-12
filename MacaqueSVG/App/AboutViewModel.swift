import Foundation
import OSLog

@MainActor
final class AboutViewModel: ObservableObject {
    @Published var currentVersion: String = ""
    @Published var currentSuccessCount: String = ""
    @Published var currentFailureCount: String = ""

    private let logger = Logger(subsystem: "club.cycleruncode.macaque.MacaqueSVG", category: "AboutViewModel")

    init() {
        loadVersionInfo()
    }

    func loadVersionInfo() {
        let info = readInfoPlist()
        currentVersion = info["CFBundleShortVersionString"] as? String ?? "1.0"
        currentSuccessCount = info["BuildSuccessCount"] as? String ?? "0"
        currentFailureCount = info["BuildFailureCount"] as? String ?? "0"
        logger.debug("Loaded version: \(self.currentVersion), builds: \(self.currentSuccessCount)/\(self.currentFailureCount)")
    }

    private func readInfoPlist() -> [String: Any] {
        let bundle = Bundle.main
        let bundleURL = bundle.bundleURL

        if bundleURL.pathExtension == "app" {
            let appPlist = bundleURL.appendingPathComponent("Contents/Info.plist")
            if let dict = NSDictionary(contentsOf: appPlist) as? [String: Any] {
                return dict
            }
        }

        return bundle.infoDictionary ?? [:]
    }
}
