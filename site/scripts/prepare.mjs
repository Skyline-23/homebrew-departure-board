import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { cp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import { siteRevision } from "./revision.mjs";

const site = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.dirname(site);
const output = path.join(site, "public");
const generated = path.join(site, "src/generated");
const hash = (bytes) =>
  createHash("sha256").update(bytes).digest("hex").slice(0, 12);
const version =
  process.env.DEPARTURE_SITE_VERSION ||
  (await readFile(path.join(root, "Casks/departure-board.rb"), "utf8")).match(
    /version "([^"]+)"/,
  )[1];
if (!/^\d+\.\d+\.\d+$/.test(version))
  throw new Error("Invalid site release version.");
execFileSync("python3", [path.join(root, "script/build-guide.py"), "--check"], {
  stdio: "inherit",
});
await rm(output, { recursive: true, force: true });
await mkdir(path.join(output, "images"), { recursive: true });
await mkdir(path.join(output, "boards"), { recursive: true });
await mkdir(generated, { recursive: true });
await cp(path.join(root, "Resources/Guide"), path.join(output, "guide"), {
  recursive: true,
});
for (const name of [
  "icon.png",
  "arrow-right.svg",
  "og-en-v1.png",
  "og-ko-v1.png",
]) {
  await cp(path.join(site, name), path.join(output, name));
}

await cp(
  path.join(site, "src/features/product/site.css"),
  path.join(output, "site.css"),
);

const icon = await sharp(path.join(site, "icon.png"))
  .resize(64)
  .png()
  .toBuffer();
const iconPath = `/icon.${hash(icon)}.png`;
await writeFile(path.join(output, iconPath), icon);
await sharp(path.join(site, "flap-tile.webp"))
  .resize({ width: 384 })
  .webp({ quality: 90 })
  .toFile(path.join(generated, "flap-tile.webp"));

const images = {};
const imageHashes = {};
for (const filename of (
  await readdir(path.join(root, "Resources/Guide/images"))
).sort()) {
  if (!filename.endsWith(".png")) continue;
  const bytes = await readFile(
    path.join(root, "Resources/Guide/images", filename),
  );
  const digest = hash(bytes);
  const stem = filename.slice(0, -4);
  const { width, height } = await sharp(bytes).metadata();
  const src = `/images/${stem}.${digest}.png`;
  imageHashes[filename] = digest;
  await writeFile(path.join(output, "images", filename), bytes);
  await writeFile(path.join(output, src), bytes);
  await writeFile(path.join(output, "guide", src), bytes);
  const widths = [
    ...new Set([320, 480, 640, 960, width].filter((size) => size <= width)),
  ].sort((a, b) => a - b);
  const variants = [];
  for (const size of widths) {
    const url = `/images/${stem}.${digest}-${size}.webp`;
    await sharp(bytes)
      .resize(size)
      .webp({ quality: 88 })
      .toFile(path.join(output, url));
    variants.push(`${url} ${size}w`);
  }
  images[filename] = { src, width, height, srcSet: variants.join(", ") };
}

for (const filename of ["index.html", "ko.html"]) {
  const target = path.join(output, "guide", filename);
  let html = await readFile(target, "utf8");
  for (const [name, image] of Object.entries(images)) {
    html = html.replaceAll(
      `src="images/${name}"`,
      `src="${image.src.replace("/images/", "images/")}"`,
    );
    const escaped = image.src
      .replace("/images/", "images/")
      .replaceAll(".", "\\.");
    html = html.replace(
      new RegExp(`<img src="${escaped}"[^>]*>`, "g"),
      (img) => {
        const sizedImage = img.replace(
          "<img ",
          `<img width="${image.width}" height="${image.height}" `,
        );
        return `<picture><source type="image/webp" srcset="${image.srcSet}" sizes="(max-width: 760px) calc(100vw - 48px), 960px">${sizedImage}</picture>`;
      },
    );
  }
  await writeFile(target, html);
}

const airports = [];
for (const airport of [
  {
    code: "ICN",
    name: "인천국제공항",
    nameEn: "Incheon International Airport",
  },
  { code: "HND", name: "하네다 공항", nameEn: "Haneda Airport" },
  {
    code: "JFK",
    name: "뉴욕 JFK 공항",
    nameEn: "John F. Kennedy International Airport",
  },
]) {
  const bytes = await readFile(
    path.join(site, "boards", `${airport.code.toLowerCase()}.webp`),
  );
  const digest = hash(bytes);
  const variants = [];
  for (const width of [480, 960, 1440, 1920]) {
    const url = `/boards/${airport.code.toLowerCase()}.${digest}-${width}.webp`;
    await sharp(bytes)
      .resize(width)
      .webp({ lossless: true })
      .toFile(path.join(output, url));
    variants.push(`${url} ${width}w`);
  }
  airports.push({
    ...airport,
    image: variants.at(-1).split(" ")[0],
    srcSet: variants.join(", "),
  });
}

await writeFile(
  path.join(generated, "site.json"),
  JSON.stringify({ version, icon: iconPath, images, airports }),
);
await writeFile(
  path.join(output, "release.json"),
  JSON.stringify({
    version,
    framework: "next",
    revision: await siteRevision(),
    images: imageHashes,
  }) + "\n",
);
await writeFile(
  path.join(output, "robots.txt"),
  "User-agent: *\nAllow: /\nSitemap: https://dpboard.skyline23.com/sitemap.xml\n",
);
await writeFile(
  path.join(output, "sitemap.xml"),
  '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' +
    ["", "ko.html", "guide/index.html", "guide/ko.html"]
      .map(
        (route) =>
          `<url><loc>https://dpboard.skyline23.com/${route}</loc></url>`,
      )
      .join("") +
    "</urlset>",
);
console.log(`Prepared Next.js assets for ${version}.`);
