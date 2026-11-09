cask "departure-board" do
  version "0.1.0"
  sha256 "b9573216e69a93a881ef3f0f14b9257ea5426ac2759e9f58e8ed3120339fc8b8"

  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v#{version}/DepartureBoard-#{version}-universal.zip"
  name "Departure Board"
  desc "Airport and railway departure boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"

  depends_on macos: :monterey

  app "Departure Board.app"
  screen_saver "Departure Board.saver"

  uninstall launchctl: "io.skyline.departureboard.refresh"

  zap trash: [
    "~/Library/Application Support/DepartureBoard",
    "~/Library/LaunchAgents/io.skyline.departureboard.refresh.plist",
    "~/Library/Preferences/io.skyline.departureboard.plist",
  ]

  caveats <<~EOS
    Choose Departure Board in System Settings > Screen Saver.
    Use the companion app to configure the live-data gateway.
  EOS
end
