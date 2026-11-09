#!/usr/bin/env python3
"""Write the formula and cask from release artifacts, without hand-edited hashes."""
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

  depends_on macos: :monterey

  app "Departure Board.app"
  screen_saver "Departure Board.saver"

  uninstall script: {{
    executable: "/bin/sh",
    args: [
      "-c",
      <<~EOS,
        /bin/launchctl bootout "gui/$(id -u)/io.skyline.departureboard.refresh" >/dev/null 2>&1 || true
        /bin/rm -f "$HOME/Library/LaunchAgents/io.skyline.departureboard.refresh.plist"
      EOS
    ],
    sudo: false,
  }}

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

source_archive = root / "outputs/DepartureBoard/dist" / f"DepartureBoard-{version}-source.tar.gz"
source_checksum = hashlib.sha256(source_archive.read_bytes()).hexdigest()
formula = (root / "script/departure-board.formula.rb.in").read_text()
formula = formula.replace("@VERSION@", version).replace("@SHA256@", source_checksum).replace("@REPOSITORY@", repository)
(root / "Formula").mkdir(exist_ok=True)
(root / "Formula/departure-board.rb").write_text(formula)
print(f"Source formula updated for {version} ({source_checksum[:12]}…).")
