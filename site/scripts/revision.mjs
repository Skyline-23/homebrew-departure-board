import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const generatedFolders = new Set([
  "node_modules",
  ".next",
  "out",
  "public",
  "generated",
]);

export async function siteRevision() {
  const digest = createHash("sha256");
  async function include(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    for (const entry of entries.sort((a, b) =>
      a.name.localeCompare(b.name, "en"),
    )) {
      if (
        generatedFolders.has(entry.name) ||
        entry.name === ".DS_Store" ||
        /^og-(en|ko)-v1\.png$/.test(entry.name)
      )
        continue;
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await include(file);
      } else if (entry.isFile()) {
        digest.update(path.relative(root, file));
        digest.update(await readFile(file));
      }
    }
  }
  await include(path.join(root, "site"));
  await include(path.join(root, "Resources/Guide"));
  digest.update(await readFile(path.join(root, "script/build-site.py")));
  return digest.digest("hex").slice(0, 16);
}
