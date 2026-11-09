#!/usr/bin/env python3
"""Write the tap definition from the release artifact, without hand-edited hashes."""
import hashlib
import os
from pathlib import Path

root = Path(__file__).resolve().parents[1]
version = os.environ.get("VERSION", "0.1.0")
repository = os.environ.get("GITHUB_REPOSITORY", "Skyline-23/homebrew-departure-board")
archive = root / "outputs/DepartureBoard/dist" / f"DepartureBoard-{version}-universal.zip"
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
text = f'''cask "departure-board" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/{repository}/releases/download/v#{{version}}/DepartureBoard-#{{version}}-universal.zip"
  name "Departure Board"
  desc "Airport and railway departure boards as a native macOS screen saver"
  homepage "https://github.com/{repository}"

  depends_on macos: ">= :monterey"

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
'''
(root / "Casks/departure-board.rb").write_text(text)
print(f"Cask updated for {version} ({checksum[:12]}…).")
