class DepartureBoard < Formula
  desc "Airport departure boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"
  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v0.7.0/DepartureBoard-0.7.0-source.tar.gz"
  sha256 "e4791b3453092a52e196562f4a90530f9c63ce85ec8d178e9f100df4caa54101"
  version "0.7.0"
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
      "#{opt_libexec}/Departure Board.app/Contents/MacOS/DepartureBoard" --install-bundles "#{opt_libexec}" || exit $?
      exec /usr/bin/open -n "/Applications/Departure Board.app" --args "$@"
    SH
  end

  def caveats
    <<~EOS
      Built locally from source; no Gatekeeper bypass is needed.
      Run departure-board once to install it in /Applications and your Screen Savers folder.
      Select Departure Board in System Settings > Wallpaper > Screen Saver.
      Enter your personal AeroDataBox RapidAPI key in Options or the companion app.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/departure-board --version")
  end
end
