# Product website

The detailed product site is `https://dpboard.skyline23.com`, hosted by the Nitroship app `dpboard`. Its default address is `https://dpboard.ntro.run`. Cloudflare manages DNS only; the product no longer uses Cloudflare Pages. The portfolio landing page remains at `https://portfolio.skyline23.com/ko/projects/departure-board` on its existing hosting.

## Build and preview

Python 3 and Node.js 22 or later are sufficient. No npm dependencies or flight-provider credentials are needed.

```sh
python3 script/build-nitroship.py
cd work/nitroship
PORT=8767 node server.mjs
```

Open `http://localhost:8767/ko` or `/` for English. The build copies the same English/Korean illustrated guide that ships inside the apps, along with public screenshots and the app icon. `/install` and `/install/ko` redirect to the corresponding guide. The upload directory contains only the public product site, its server, Dockerfile and deployment settings.

`site/nitroship/nitroship.json` extracts `/app/public` from the image for Nitroship's static CDN. Fallback platform redirects run in the Incheon region, with zero idle instances and at most one active instance. `/healthz` is the runtime health check. These hosting settings do not affect the desktop app's flight-provider requests.

## Deploy

Install the official Nitroship CLI and sign in, then run:

```sh
python3 script/build-nitroship.py
ntro deploy work/nitroship --app dpboard --team buseong-kim-f9isa5 --preview
ntro promote <ready-deployment-id> --app dpboard --team buseong-kim-f9isa5
```

Check the preview before promotion: English and Korean pages, all guide images, both install redirects, the single Get button, platform selection, and direct GitHub ZIP downloads. After promotion, check both `dpboard.ntro.run` and `dpboard.skyline23.com` over HTTPS. A ready preview alone does not activate the production address.

The custom domain uses a DNS-only CNAME from `dpboard` to `via.nitroship.co`. Nitroship verifies ownership and issues the TLS certificate. Leave the apex, blog and portfolio DNS records unchanged.

```sh
ntro domains list --app dpboard --team buseong-kim-f9isa5
ntro domains verify dpboard.skyline23.com --app dpboard --team buseong-kim-f9isa5 --wait
```

## Downloads and request usage

The single Get button links directly to the latest GitHub release installer for the visitor's desktop OS. `download.js` reads the local browser user agent and sets the link without a network request. Alternative OS links are direct GitHub asset URLs inside a disclosure.

Without JavaScript, `/download` detects the OS and returns an uncached redirect to the same GitHub asset. An unknown/mobile browser gets one platform selector and one Get button. Legacy `/download/macos`, `/download/windows-x64` and `/download/windows-arm64` URLs also redirect directly. Nitroship does not fetch, buffer, cache or proxy installers.

Every release includes `DepartureBoard-universal.zip`; Windows setup executables use stable `DepartureBoard-win-x64-Setup.exe` and `DepartureBoard-win-arm64-Setup.exe` filenames. Optional ZIPs remain on the release page. All URLs use `releases/latest/download/`, so new tags require no website edit and visitors never need to navigate the GitHub release page.

The page makes no flight-provider requests, client-side release lookups or background polling. No API keys, quota limits or automatic quota-based stop are added to the desktop clients.

## Social previews

English and Korean use separate 1200×630 PNG cards with the real app icon and screen capture. Both Open Graph and Twitter metadata point at these absolute public URLs. Regenerate the layout with `python3 script/build-og-preview.py`, serve `work/og`, and export each HTML page at 1200×630 to `site/og-en-v1.png` and `site/og-ko-v1.png`. Change the asset version in the HTML when replacing an already published card.

## Interactive airport preview

The editorial landing page uses an ivory background, one yellow Get button and three split-flap airport codes. The navigation stays fixed across the whole page, and the install section has a separate outlined guide button. Scrolling selects Incheon, Haneda and JFK. The airport codes and the app's real sample renders turn together, with short staggered transitions. The same three airports can be selected with native radio controls. The display opens in a native dialog with Escape dismissal and focus restoration.

`site/airport-demo.js` owns page events, stale image requests, scroll state and teardown. `site/board-transition.js` owns raster-strip animation and cancellation. `site/airport-data.js` owns the three featured previews. The 1920×1080 WebP files in `site/boards` are lossless exports of the app's fixed-date sample PNG renders. The decorative blank split-flap tile was generated for this page. Its letters remain selectable UI state rather than part of the bitmap.

Only the initial preview loads on first view. Other previews load on selection or a scroll transition. There is no autoplay, flight-provider request or GitHub API lookup. Reduced-motion mode disables scroll pinning, flip animation and section reveals. The controller cancels unfinished image transitions and releases listeners and observers when the page is left. The date is the visitor's local date.
