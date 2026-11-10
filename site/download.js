(() => {
  const agent = navigator.userAgent;
  if (/Android|iPhone|iPad|iPod/i.test(agent)) return;
  let filename;
  if (/Windows/i.test(agent)) {
    filename = /ARM|aarch64/i.test(agent) ? 'DepartureBoard-win-arm64.zip' : 'DepartureBoard-win-x64.zip';
  } else if (/Macintosh/i.test(agent)) {
    filename = 'DepartureBoard-universal.zip';
  }
  if (!filename) return;
  const url = 'https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/' + filename;
  for (const button of document.querySelectorAll('[data-download]')) button.href = url;
})();
