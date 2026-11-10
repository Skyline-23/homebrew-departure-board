import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { setImmediate } from "node:timers/promises";
import vm from "node:vm";
import downloads from "../site/download-handler.mjs";

const source = await readFile(
  new URL("../site/download.js", import.meta.url),
  "utf8",
);
const cases = [
  {
    agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    expected: "DepartureBoard-universal.dmg",
  },
  {
    agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    expected: "DepartureBoard-win-x64-Setup.exe",
  },
  {
    agent: "Mozilla/5.0 (Windows NT 10.0; ARM64)",
    expected: "DepartureBoard-win-arm64-Setup.exe",
  },
  {
    agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    architecture: "arm",
    expected: "DepartureBoard-win-arm64-Setup.exe",
  },
  { agent: "Mozilla/5.0 (iPhone)", expected: "/download?choose=1" },
  {
    agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    touch: 5,
    expected: "/download?choose=1",
  },
  { agent: "Mozilla/5.0 (X11; Linux x86_64)", expected: "/download?choose=1" },
];

for (const item of cases) {
  const links = [{ href: "/download" }, { href: "/download" }];
  const note = { textContent: "" };
  const context = {
    document: {
      documentElement: { lang: "ko" },
      querySelectorAll: (selector) =>
        selector === "[data-download]" ? links : [note],
    },
    navigator: {
      userAgent: item.agent,
      platform: item.touch ? "MacIntel" : "",
      maxTouchPoints: item.touch || 0,
      userAgentData: item.architecture
        ? {
            platform: "Windows",
            getHighEntropyValues: async () => ({
              architecture: item.architecture,
            }),
          }
        : undefined,
    },
  };
  vm.runInNewContext(source, context);
  await setImmediate();
  assert.ok(
    links.every((link) => link.href.endsWith(item.expected)),
    item.agent,
  );
  assert.ok(note.textContent.length > 0);
}

for (const [platform, filename] of [
  ["macos", "DepartureBoard-universal.dmg"],
  ["windows-x64", "DepartureBoard-win-x64-Setup.exe"],
  ["windows-arm64", "DepartureBoard-win-arm64-Setup.exe"],
]) {
  const response = await downloads.fetch(
    new Request(`https://example.test/download/${platform}`),
  );
  assert.equal(response.status, 302);
  assert.ok(response.headers.get("location").endsWith(filename));
  assert.equal(response.headers.get("cache-control"), "no-store");
}

const manual = await downloads.fetch(
  new Request("https://example.test/download?choose=1", {
    headers: { "user-agent": "Mozilla/5.0 (Macintosh)" },
  }),
);
assert.equal(manual.status, 200);
assert.ok((await manual.text()).includes('name="platform"'));
console.log("OS-specific downloads and manual selection passed.");
