import AppKit

private struct RuntimeState: Decodable {
    let appVersion: String
    let processID: Int
}

private enum InstallationCheckError: LocalizedError {
    case missingVersion
    case startupTimedOut
    case appearedInDock
    case missingSetupWindow

    var errorDescription: String? {
        switch self {

        case .missingVersion:
            return "Pass the expected release version as the first argument."
        case .startupTimedOut:
            return "The installed app did not complete startup."
        case .appearedInDock:
            return "The app appeared as a Dock application."
        case .missingSetupWindow:
            return "First launch did not show the app's setup window."
        }
    }
}

private struct InstalledApplicationCheck {
    private let bundleIdentifier = "com.skyline23.departureboard"
    private let applicationURL = URL(fileURLWithPath: "/Applications/Departure Board.app")
    private let runtimeStateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DepartureBoard/Runtime.plist")

    func run(expectedVersion: String) throws {

        var launchError: Error?
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        ) { _, error in
            launchError = error
        }

        let application = try waitForStartup(expectedVersion: expectedVersion) {
            launchError
        }
        defer {

            application.terminate()
        }

        guard application.activationPolicy == .accessory else {

            throw InstallationCheckError.appearedInDock
        }

        RunLoop.current.run(until: Date().addingTimeInterval(2))

        guard hasVisibleWindow(for: application) else {

            throw InstallationCheckError.missingSetupWindow
        }

        print("Installed version \(expectedVersion) started and showed setup without a Dock icon.")
    }

    private func waitForStartup(
        expectedVersion: String,
        launchError: () -> Error?
    ) throws -> NSRunningApplication {

        let deadline = Date().addingTimeInterval(30)

        while Date() < deadline {

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))

            if let error = launchError() {

                throw error
            }

            guard let application = singleRunningApplication() else {

                continue
            }

            guard let runtimeState = readRuntimeState() else {

                continue
            }

            let versionMatches = runtimeState.appVersion == expectedVersion
            let processMatches = runtimeState.processID == Int(application.processIdentifier)

            if versionMatches && processMatches {

                return application
            }
        }

        throw InstallationCheckError.startupTimedOut
    }

    private func singleRunningApplication() -> NSRunningApplication? {

        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        let activeApplications = applications.filter { application in
            !application.isTerminated && application.activationPolicy != .prohibited
        }

        guard activeApplications.count == 1 else {

            return nil
        }

        return activeApplications.first
    }

    private func readRuntimeState() -> RuntimeState? {

        guard let data = try? Data(contentsOf: runtimeStateURL) else {

            return nil
        }

        return try? PropertyListDecoder().decode(RuntimeState.self, from: data)
    }

    private func hasVisibleWindow(for application: NSRunningApplication) -> Bool {

        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
        let windows = windowList as? [[String: Any]] ?? []
        let processID = Int(application.processIdentifier)

        return windows.contains { window in
            let ownerID = window[kCGWindowOwnerPID as String] as? Int
            return ownerID == processID
        }
    }
}

do {

    guard let expectedVersion = CommandLine.arguments.dropFirst().first else {

        throw InstallationCheckError.missingVersion
    }

    try InstalledApplicationCheck().run(expectedVersion: expectedVersion)
} catch {

    fputs("Installation check failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
