# Product website

The detailed product site is `https://dpboard.skyline23.com`, hosted by the Nitroship app `dpboard`. Its default address is `https://dpboard.ntro.run`. Cloudflare manages DNS only; the product no longer uses Cloudflare Pages. The portfolio landing page remains at `https://portfolio.skyline23.com/ko/projects/departure-board` on its existing hosting.

## Build and preview

The product pages use Next.js 16 with the App Router and a static export. Python 3 and Node.js 22 or later are required. Install the pinned dependencies before building.

```sh
npm ci --prefix site
python3 script/build-nitroship.py
cd work/nitroship
PORT=8767 node server.mjs
```

Open `http://localhost:8767/ko` or `/` for English. The build copies the same English/Korean illustrated guide that ships inside the apps, along with public screenshots and the app icon. `/install` and `/install/ko` redirect to the corresponding guide. The upload directory contains only the public product site, its server, Dockerfile and deployment settings.

`nitroship.json` extracts `/app/public` from the image for Nitroship's static CDN. Fallback platform redirects run in the Incheon region, with zero idle instances and at most one active instance. `/healthz` is the runtime health check. These hosting settings do not affect the desktop app's flight-provider requests.

## Deploy

Install the official Nitroship CLI and sign in, then run:

```sh
python3 script/build-nitroship.py
ntro deploy work/nitroship --app dpboard --team buseong-kim-f9isa5 --preview
ntro promote <ready-deployment-id> --app dpboard --team buseong-kim-f9isa5
```

Check the preview before promotion: English and Korean pages, all guide images, both install redirects, the fixed Install and hero Get actions, platform selection, and direct GitHub DMG/EXE downloads. After promotion, check both `dpboard.ntro.run` and `dpboard.skyline23.com` over HTTPS. A ready preview alone does not activate the production address.

The custom domain uses a DNS-only CNAME from `dpboard` to `via.nitroship.co`. Nitroship verifies ownership and issues the TLS certificate. Leave the apex, blog and portfolio DNS records unchanged.

```sh
ntro domains list --app dpboard --team buseong-kim-f9isa5
ntro domains verify dpboard.skyline23.com --app dpboard --team buseong-kim-f9isa5 --wait
```

## Downloads and request usage

The hero Get button and fixed-navigation Install button link directly to the latest GitHub release installer for the visitor's desktop OS. The download enhancement reads the local browser user agent and sets the link without a network request. The detected operating system is shown below Get. The “different operating system” disclosure exposes direct GitHub links for macOS, Windows x64 and Windows ARM64. Chromium architecture hints improve Windows ARM64 selection without a network request.

Without JavaScript, `/download` detects the OS and returns an uncached redirect to the same GitHub asset. An unknown/mobile browser gets one platform selector and one Get button. `/download?choose=1` explicitly opens that selector. Legacy `/download/macos`, `/download/windows-x64` and `/download/windows-arm64` URLs also redirect directly. Nitroship does not fetch, buffer, cache or proxy installers.

The primary macOS asset is `DepartureBoard-universal.dmg`; Windows setup executables use stable `DepartureBoard-win-x64-Setup.exe` and `DepartureBoard-win-arm64-Setup.exe` filenames. Optional ZIPs remain on the release page. All URLs use `releases/latest/download/`, so new tags require no website edit and visitors never need to navigate the GitHub release page.

The page makes no flight-provider requests, client-side release lookups or background polling. No API keys, quota limits or automatic quota-based stop are added to the desktop clients.

## Social previews

English and Korean use separate 1200×630 PNG cards with the real app icon and screen capture. Both Open Graph and Twitter metadata point at these absolute public URLs. CI renders both cards with `python3 script/build-og-preview.py --render`. Next.js metadata selects the language-specific card and includes the release version in its URL.

## Interactive airport preview

The editorial landing page uses an ivory background, a yellow Get button and three split-flap airport codes. The navigation stays fixed across the whole page with an Install action. Both download actions select the same latest file for the visitor. Installation steps live in the guide, and alternate platform links stay in a compact footer disclosure. Scrolling selects Incheon, Haneda and JFK. The airport codes and the app's real sample renders turn together, with short staggered transitions. The same three airports can be selected with native radio controls. The display opens in a native dialog with Escape dismissal and focus restoration.

`site/airport-demo.js` owns page events, stale image requests, scroll state and teardown. `site/board-transition.js` owns raster-strip animation and cancellation. `site/airport-data.js` exposes the three featured previews from the generated asset manifest. The 1920×1080 WebP files in `site/boards` are lossless exports of the app's fixed-date sample PNG renders. The decorative blank split-flap tile was generated for this page. Its letters remain selectable UI state rather than part of the bitmap.

Only the initial preview loads on first view. Other previews load on selection or a scroll transition. There is no autoplay, flight-provider request or GitHub API lookup. Reduced-motion mode disables scroll pinning, flip animation and section reveals. The controller cancels unfinished image transitions and releases listeners and observers when the page is left. The date is the visitor's local date.

## Automatic deployment

The repository-root `nitroship.json` builds the product site with `site/nitroship/Dockerfile.git`. It copies only the public site, bundled guide and runtime redirect handler into the final image. The Nitroship GitHub App is limited to this repository, with `main` as the production branch. Preview auto-deployments are disabled to avoid building every working-branch update.

GitHub validation separates site/guide checks from native app checks. Superseded validation runs are cancelled. Windows caches NuGet packages and the verified installer-compiler download, and builds the desktop application only when publishing its runtime package. Tagged releases create a draft, upload all platform assets, and publish the complete release together.

## Next.js rendering and images

`site/components/ProductPage.jsx` renders the page from shared English/Korean copy. The page and metadata are generated at build time. A small client component starts the OS detection and lazily loads the existing airport controller after hydration. Normal anchors avoid background route prefetches.

`site/scripts/prepare.mjs` creates responsive WebP variants, content-addressed screenshot URLs and a small app icon. Native board previews use lossless variants at 480, 960, 1440 and 1920 pixels. The original full-resolution board loads when the visitor opens its detail view. The illustrated guide keeps its offline source and gains responsive images in the website build.

The Nitroship runtime serves the exported files and redirects downloads to GitHub Releases. The CI cache covers npm and Next.js build data. Browser checks cover desktop/mobile overflow, airport switching, dialog dismissal, language metadata and image loading. The deployed manifest must match the current source revision before the live rollout check can pass.
