class DepartureBoard < Formula
  desc "Airport and railway boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"
  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v0.2.0/DepartureBoard-0.2.0-source.tar.gz"
  sha256 "e65781c4c08b1c192427f7fa64c782bb75634a246a7666cdb3d75aac0e256b65"
  version "0.2.0"
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
      exec /usr/bin/open -n "#{opt_libexec}/Departure Board.app" --args "$@"
    SH
  end

  def post_install
    # Stable opt paths continue to work when Homebrew upgrades the Cellar version.
    links = {
      Pathname.new(Dir.home)/"Applications/Departure Board.app" => opt_libexec/"Departure Board.app",
      Pathname.new(Dir.home)/"Library/Screen Savers/Departure Board.saver" => opt_libexec/"Departure Board.saver",
    }
    links.each do |destination, source|
      destination.dirname.mkpath
      if destination.exist? && !destination.symlink?
        opoo "Existing #{destination} was preserved. Remove the old cask before linking this formula."
        next
      end
      destination.unlink if destination.symlink?
      ln_s source, destination
    end
  end

  def caveats
    <<~EOS
      Built locally from source; no Gatekeeper bypass is needed.
      Open ~/Applications/Departure Board.app or run: departure-board
      Select Departure Board in System Settings > Screen Saver.
      Configure the live-data gateway in the companion app.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/departure-board --version")
  end
end
