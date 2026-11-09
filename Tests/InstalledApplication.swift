import AppKit

let expectedVersion = CommandLine.arguments[1]
let identifier = "com.skyline23.departureboard"
let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = true
var launchError: Error?
NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Departure Board.app"),
                                  configuration: configuration) { _, error in launchError = error }
let deadline = Date().addingTimeInterval(30)
let stateURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/DepartureBoard/Runtime.plist")
var running: NSRunningApplication?
while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    if let error = launchError { fatalError(error.localizedDescription) }
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        .filter { !$0.isTerminated && $0.activationPolicy != .prohibited }
    if apps.count == 1, let data = try? Data(contentsOf: stateURL),
       let state = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
       state["appVersion"] as? String == expectedVersion,
       state["processID"] as? Int == Int(apps[0].processIdentifier) {
        running = apps[0]
        break
    }
}
guard let app = running else { fatalError("The installed app did not complete startup.") }
guard app.activationPolicy == .accessory else { fatalError("The app appeared as a Dock application.") }
RunLoop.current.run(until: Date().addingTimeInterval(2))
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
guard windows.contains(where: { ($0[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier) })
else { fatalError("First launch did not show the app's setup window.") }
print("Installed version \(expectedVersion) started, showed setup, and retained accessory activation policy.")
app.terminate()
