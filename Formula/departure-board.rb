class DepartureBoard < Formula
  desc "Airport and railway boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"
  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v0.2.1/DepartureBoard-0.2.1-source.tar.gz"
  sha256 "4b8a031720fa5bdd0de118b4404c420f03a44fcdb8adee7232e9224fd30c8f3d"
  version "0.2.1"
  license "MIT"

  depends_on macos: :monterey

  def install
    ENV["VERSION"] = version.to_s
    ENV["BUILD_ARCH"] = Hardware::CPU.arch.to_s
    system "bash", "script/build.sh"
    libexec.install "outputs/DepartureBoard/dist/Departure Board.app"
    libexec.install "outputs/DepartureBoard/dist/Departure Board.saver"

    (bin/"departure-board").write <<~SH
      #!/bin/bash
      if [[ "${1:-}" == "--version" ]]; then
        exec "#{opt_libexec}/Departure Board.app/Contents/MacOS/DepartureBoard" --version
      fi
      exec /usr/bin/open -n "#{opt_libexec}/Departure Board.app" --args --register-bundles "#{opt_libexec}" "$@"
    SH
  end

  def caveats
    <<~EOS
      Built locally from source; no Gatekeeper bypass is needed.
      Run departure-board once to register it in Applications and Screen Savers.
      Select Departure Board in System Settings > Screen Saver.
      Configure the live-data gateway in the companion app.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/departure-board --version")
  end
end
