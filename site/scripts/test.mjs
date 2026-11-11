import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import {
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  rm,
  symlink,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const temporary = await mkdtemp(path.join(os.tmpdir(), "departure-next-test-"));
const output = path.join(root, "work/next-validation");
await mkdir(output, { recursive: true });
await symlink(
  path.join(root, "work/site"),
  path.join(temporary, "public"),
  "dir",
);
await copyFile(
  path.join(root, "site/nitroship/server.mjs"),
  path.join(temporary, "server.mjs"),
);
await copyFile(
  path.join(root, "site/download-handler.mjs"),
  path.join(temporary, "download-handler.mjs"),
);
const server = spawn(process.execPath, [path.join(temporary, "server.mjs")], {
  cwd: temporary,
  env: { ...process.env, PORT: "18767" },
  stdio: "inherit",
});
let browser;
try {
  let ready = false;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      ready = (await fetch("http://127.0.0.1:18767/healthz")).ok;
    } catch {}
    if (ready) break;
    await delay(100);
  }
  assert.ok(ready, "The exported site must start.");
  browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome",
    headless: true,
  });
  for (const [name, viewport, motion] of [
    ["desktop", { width: 1440, height: 1024 }, "no-preference"],
    ["mobile", { width: 390, height: 844 }, "reduce"],
  ]) {
    const context = await browser.newContext({
      viewport,
      reducedMotion: motion,
    });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") errors.push(message.text());
    });
    await page.goto("http://127.0.0.1:18767/ko.html", {
      waitUntil: "networkidle",
    });
    assert.equal(await page.locator("html").getAttribute("lang"), "ko");
    assert.equal(
      await page.locator("body").getAttribute("data-site-framework"),
      "next",
    );
    assert.ok(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    );
    await page
      .getByRole("radio", { name: "인천 ICN", exact: true })
      .press("ArrowRight");
    await page.waitForFunction(
      () =>
        document.querySelector("#airport-board").src.includes("/hnd.") &&
        !document.querySelector("#airport-expand").hasAttribute("aria-busy"),
    );
    await page
      .getByRole("button", { name: "전광판 크게 보기", exact: true })
      .click();
    assert.equal(
      await page.locator("#airport-dialog").evaluate((dialog) => dialog.open),
      true,
    );
    await page.keyboard.press("Escape");
    assert.equal(
      await page.locator("#airport-dialog").evaluate((dialog) => dialog.open),
      false,
    );
    assert.equal(
      await page.evaluate(() => document.activeElement.id),
      "airport-expand",
    );
    await page
      .getByText("혹시 이 운영체제가 아닌가요?", { exact: true })
      .click();
    assert.equal(await page.locator(".platform-options a").count(), 3);
    await page
      .getByText("혹시 이 운영체제가 아닌가요?", { exact: true })
      .click();
    await page
      .getByRole("heading", { name: "내 화면을 보기 편하게", exact: true })
      .scrollIntoViewIfNeeded();
    await page.waitForFunction(() =>
      [...document.querySelectorAll(".settings img")].every(
        (image) => image.complete && image.naturalWidth > 0,
      ),
    );
    const imageSources = await page
      .locator(".settings img")
      .evaluateAll((images) => images.map((image) => image.currentSrc));
    assert.ok(
      imageSources.every((src) => src.endsWith(".webp")),
      "Settings must load responsive WebP images.",
    );
    assert.equal(
      await page
        .locator("header")
        .evaluate((header) => header.getBoundingClientRect().top),
      0,
    );
    await page.evaluate(() => scrollTo({ top: 0, behavior: "instant" }));
    await page.waitForFunction(() => {
      const selected = document.querySelector(
        'input[name="airport"]:checked',
      ).value;
      const letters = [...document.querySelectorAll(".flap-letter")]
        .map((letter) => letter.textContent)
        .join("");
      const source = document.querySelector("#airport-board").src;
      return (
        !document.querySelector("#airport-expand").hasAttribute("aria-busy") &&
        letters === selected &&
        source.includes(`/${selected.toLowerCase()}.`) &&
        document
          .getAnimations()
          .every((animation) => animation.playState !== "running")
      );
    });
    await page.screenshot({ path: path.join(output, `${name}.png`) });
    await page.getByRole("link", { name: "EN", exact: true }).click();
    await page.waitForLoadState("networkidle");
    assert.equal(await page.locator("html").getAttribute("lang"), "en");
    assert.ok(
      (
        await page.locator('meta[property="og:image"]').getAttribute("content")
      ).includes("og-en-v1.png"),
    );
    assert.deepEqual(
      errors,
      [],
      "The page must hydrate and interact without browser errors.",
    );
    await context.close();
    console.log(
      `PASS ${name} layout, interaction, images, language and hydration.`,
    );
  }
  const manifest = JSON.parse(
    await readFile(path.join(root, "work/site/release.json"), "utf8"),
  );
  assert.equal(manifest.framework, "next");
} finally {
  await browser?.close();
  server.kill();
  await rm(temporary, { recursive: true, force: true });
}
