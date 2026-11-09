class DepartureBoard < Formula
  desc "Airport and railway boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"
  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v0.4.2/DepartureBoard-0.4.2-source.tar.gz"
  sha256 "605fb10bf544430ae15c0505683b3ed7a70bc69da513c9934bb558eb9763adbc"
  version "0.4.2"
  license "MIT"

  depends_on macos: :monterey

  def install
    ENV["VERSION"] = version.to_s
    system "bash", "script/build.sh"
    libexec.install "outputs/DepartureBoard/dist/Departure Board.app"
    libexec.install "outputs/DepartureBoard/dist/Departure Board.saver"
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
