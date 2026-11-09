class DepartureBoard < Formula
  desc "Airport and railway boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"
  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v0.5.0/DepartureBoard-0.5.0-source.tar.gz"
  sha256 "0e4f04f00c616c96f712070adb1b5d2be2c423dd212cfa6baba97d2b2fce78e1"
  version "0.5.0"
  license "MIT"

  depends_on macos: :monterey

  def install
    ENV["VERSION"] = version.to_s
    system "bash", "script/build.sh"
    libexec.install "work/Build.noindex/Bundles/Departure Board.app"
    libexec.install "work/Build.noindex/Bundles/Departure Board.saver"
    libexec.install "script/sign-local.sh"

    (bin/"departure-board").write <<~SH
      #!/bin/bash
      if [[ "${1:-}" == "--version" ]]; then
        exec "#{opt_libexec}/Departure Board.app/Contents/MacOS/DepartureBoard" --version
      fi
      "#{opt_libexec}/sign-local.sh" || exit $?
      exec /usr/bin/open -n "#{opt_libexec}/Departure Board.app" --args --register-bundles "#{opt_libexec}" "$@"
    SH
  end

  def caveats
    <<~EOS
      Built locally from source; no Gatekeeper bypass is needed.
      Run departure-board once to register it in Applications and Screen Savers.
      Select Departure Board in System Settings > Wallpaper > Screen Saver.
      Enter your personal AeroDataBox RapidAPI key in Options or the companion app.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/departure-board --version")
  end
end
