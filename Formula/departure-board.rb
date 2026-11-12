class DepartureBoard < Formula
  desc "Airport departure boards as a native macOS screen saver"
  homepage "https://github.com/Skyline-23/homebrew-departure-board"
  url "https://github.com/Skyline-23/homebrew-departure-board/releases/download/v0.7.8/DepartureBoard-0.7.8-source.tar.gz"
  sha256 "c93c1c663dc0880090afda755258651ed69f721357b7fc0ac9b690f62e959ee4"
  version "0.7.8"
  license "MIT"

  depends_on macos: :monterey

  resource "sparkle" do
    url "https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-2.10.1.tar.xz"
    sha256 "1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27"
  end

  def install
    ENV["VERSION"] = version.to_s
    resource("sparkle").stage(buildpath/"sparkle")
    ENV["SPARKLE_ROOT"] = (buildpath/"sparkle").to_s
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
