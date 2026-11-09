cask "departure-board" do
  version "0.2.1"
  sha256 "ecc21ae4f82c237605eed5d4a69186cd74bf4539ccd7a4632fcf642b04095ecf"

  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v#{version}/DepartureBoard-#{version}-universal.zip"
  name "Departure Board"
  desc "Airport and railway departure boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"

  depends_on macos: :monterey

  app "Departure Board.app"
  screen_saver "Departure Board.saver"

  uninstall script: {
    executable: "/bin/sh",
    args: [
      "-c",
      <<~EOS,
        /bin/launchctl bootout "gui/$(id -u)/io.skyline.departureboard.refresh" >/dev/null 2>&1 || true
        /bin/rm -f "$HOME/Library/LaunchAgents/io.skyline.departureboard.refresh.plist"
      EOS
    ],
    sudo: false,
  }

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
