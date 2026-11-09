cask "departure-board" do
  version "0.7.0"
  sha256 "718c9c949d95244522423e5fdae20856b21ed78c19d8622f92e41bc52a42d26b"

  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v#{version}/DepartureBoard-#{version}-universal.zip"
  name "Departure Board"
  desc "Airport departure boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"

  depends_on macos: :monterey

  app "Departure Board.app"
  screen_saver "Departure Board.saver"

  uninstall script: {
    executable: "/bin/sh",
    args: [
      "-c",
      <<~EOS,
        /bin/launchctl bootout "gui/$(id -u)/com.skyline23.departureboard.refresh" >/dev/null 2>&1 || true
        /bin/rm -f "$HOME/Library/LaunchAgents/com.skyline23.departureboard.refresh.plist"
      EOS
    ],
    sudo: false,
  }

  zap trash: [
    "~/Library/Application Support/DepartureBoard",
    "~/Library/LaunchAgents/com.skyline23.departureboard.refresh.plist",
    "~/Library/Preferences/com.skyline23.departureboard.plist",
  ]

  caveats <<~EOS
    Choose Departure Board in System Settings > Screen Saver.
    Use the companion app to enter your own AeroDataBox RapidAPI key.
  EOS
end
