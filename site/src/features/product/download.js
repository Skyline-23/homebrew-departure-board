export function initDownloads() {
  let active = true;
  const release =
    "https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/";
  const korean = document.documentElement.lang === "ko";
  const agent = navigator.userAgent;
  const hints = navigator.userAgentData;
  const touchMac =
    /Mac/i.test(navigator.platform || "") && navigator.maxTouchPoints > 1;
  const mobile = /Android|iPhone|iPad|iPod/i.test(agent) || touchMac;

  function showPlatform(platform, architecture = "") {
    if (!active) return;
    const windows = platform === "windows";
    const arm = /arm|aarch64/i.test(architecture);
    const filename = windows
      ? `DepartureBoard-win-${arm ? "arm64" : "x64"}-Setup.exe`
      : "DepartureBoard-universal.dmg";
    const label = windows
      ? `Windows · ${arm ? "ARM64" : "x64"} · EXE`
      : "macOS · Apple Silicon / Intel · DMG";
    for (const link of document.querySelectorAll("[data-download]"))
      link.href = release + filename;
    for (const note of document.querySelectorAll("[data-detected-platform]"))
      note.textContent = label;
  }

  const platform = hints?.platform || agent;
  if (!mobile && /Windows/i.test(platform)) {
    showPlatform("windows", agent);
    if (typeof hints?.getHighEntropyValues === "function") {
      hints
        .getHighEntropyValues(["architecture"])
        .then((values) => {
          showPlatform("windows", values.architecture);
        })
        .catch(() => {
          // The synchronous user-agent fallback remains available if hints are denied.
        });
    }
  } else if (!mobile && /macOS|Macintosh/i.test(platform)) {
    showPlatform("macos");
  } else {
    for (const link of document.querySelectorAll("[data-download]"))
      link.href = "/download?choose=1";
    for (const note of document.querySelectorAll("[data-detected-platform]")) {
      note.textContent = korean
        ? "설치할 컴퓨터를 선택하세요"
        : "Choose the computer to install on";
    }
  }
  return () => {
    active = false;
  };
}
