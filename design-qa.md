# Editorial product page QA

## Visual target and evidence

- Selected direction is option 1, the ivory boarding-pass editorial layout chosen on 2026-11-10.
- Source visual truth is `work/design/selected-reference.png`, copied from `exec-a502a2e8-fd2a-435c-a66e-dd75188c0dae.png` in the session's generated-image output.
- Source pixels are 1488 × 1058. The comparison normalizes this to 1440 × 1024.
- Browser-rendered implementation is `work/design/editorial-desktop-final.png`, 1440 × 1024 CSS pixels, device scale factor 1, Korean route, ICN selected, at the top of the page.
- Full-view comparison is `work/design/editorial-comparison-final.jpg`. The source and implementation appear together.
- Focused typography, airport-code, navigation and button comparison is `work/design/editorial-focused-final.jpg`.
- Additional rendered evidence includes `editorial-mobile-final.png` at 390 × 844, `editorial-320.png` at 320 × 740, `editorial-768.png` at 768 × 1024, `editorial-1280.png` at 1280 × 800, `editorial-english-final.png`, `editorial-scroll-hnd.png` and `editorial-features.png` under `work/design/`.
- These captures are local validation artifacts. The source implementation and its public assets are versioned separately.

## Comparison history

1. Initial implementation had a missing arrow image because the local server served SVG as an octet stream. The heading was narrower than the selected reference, and the preview used Korean flight labels. Result was blocked. Added the SVG MIME type, refined headline scale and spacing, and exported the app's English ICN sample at 1920 × 1080. Evidence is `editorial-comparison-v1.jpg` and `editorial-comparison-v2.jpg`.
2. The English headline crossed the vertical divider. Result was blocked. Reduced its desktop display size and recaptured `editorial-english-final.png`. It now fits its column. Korean spacing was also relaxed for readability. The final full-view and focused comparisons show the revised composition.
3. At short desktop heights, a pinned scene could extend below the viewport. The scene now uses normal document flow below 720px height. Checked 1280 × 600 with no horizontal overflow and equal hero/scene heights, so the whole preview is reachable by scrolling.

## Required fidelity surfaces

- Fonts and typography pass. Heavy two-line display type, compact masthead, tracked airport label and restrained supporting copy follow the reference hierarchy. Platform system-font rendering has minor glyph differences from the generated mock. English uses a separate size to fit its longer second line.
- Spacing and layout pass. The thin masthead rule, 52/48 introduction split, vertical divider, three airport tiles, yellow action at lower left and uncropped board at lower right match the selected composition. On narrow screens the sections stack and the complete board retains its aspect ratio.
- Colors and tokens pass. Ivory `#faf6ed`, near-black type and yellow `#ffb51d` form the page palette. The board uses its native app colors. Browser screenshot compression shifts their appearance slightly, so app assets were checked directly rather than recolored to match the capture.
- Image quality and assets pass. Real app icon and native board renders are used. The 1920 × 1080 boards are lossless WebP. The blank decorative flap tile is a generated raster asset, while the displayed airport code is live text. The arrow is the official Phosphor SVG with its license in `THIRD_PARTY_NOTICES.md`. There is no crop or stretched board image.
- Copy and content pass. The chosen Korean headline and subtitle remain intact. The date reflects the visitor's local date. A small sample label and OS compatibility note provide context below the action. These additions and the unwarped native board are intentional practical differences from the static mock.

## Interaction and runtime checks

- Scroll changes ICN → HND → JFK. Matching radio state, code text and image are confirmed after transitions settle.
- Direct selection works with native radio controls. Fourteen animated raster rows were observed at mobile width. Rapid keyboard navigation settles on JFK with matching code/image and no leftover busy state.
- Clicking the board opens the native dialog. Escape closes it and returns focus to the board button.
- Reduced motion removes pinned scrolling and flip effects. The selected airport still updates. No continuous autoplay or polling is present.
- Page navigation, language switching and returning from the guide restore working controls. Korean and English pages each contain one main, one h1 and one primary download link.
- No horizontal overflow at 320, 390, 768, 1280 or 1440 CSS-pixel widths. A 1280 × 600 window also remains scrollable without overflow.
- Browser warning/error logs were empty during the tested interactions.
- The single Get action downloaded the published macOS ZIP directly from GitHub. SHA-256 matched `1c0faf8f8736258f1a468e26969ab63e8363beffc820e6d8014544e62b589193`. Windows links continue to target the stable x64/ARM64 Setup.exe assets.
- The installation guide opened from the header. The visible macOS screenshot loaded successfully. Bundled guide validation and site builds passed.
- `script/lint.sh`, `script/function-spacing.py`, JavaScript syntax checks, Prettier checks and `git diff --check` passed.

## Follow-up navigation and install action

The user requested an installation action and persistent top navigation during final review. The whole-page fixed navigation now stays at y=0 with a 64px height while the install section is visible. `work/design/editorial-install-button.png` shows the outlined installation-guide action below the installation details. Clicking it opened the Korean guide. The primary download-link count remains one. The initial composition was recaptured and compared in `editorial-comparison-final.jpg` after these changes.

## Final user-directed changes

The user clarified that Install belongs in the fixed navigation and that the long installation block is unnecessary. The final page therefore has an Install action in the masthead and a Get action in the hero, both targeting the same platform-specific latest asset. The duplicate compatibility paragraphs, Homebrew command and large installation section are removed. Other platform links remain in a compact footer disclosure. The header Install action was clicked and downloaded the published macOS ZIP successfully. At 320px the header, Install action and language link fit with no overflow.

The fixed browser test viewport has been cleared. At the actual 2200 × 1452 window, the preview measures 1138 × 640 CSS pixels. The preview row no longer grows to fill excess vertical space. At 1440 × 1024 it measures 972 × 547, and at 390 × 844 it measures 350 × 197. The complete native image remains contained at shorter heights. Evidence is `editorial-final-nav.png`, `editorial-final-nav-mobile.png`, `editorial-fluid-actual.png` and `editorial-fluid-1440.png`. The final full-view comparison has been regenerated after these changes.

## Remaining scope

No actionable P0, P1 or P2 design findings remain. Native Windows rendering and installation results are documented in `Windows/VALIDATION.md`; this page-only change does not provide new native-device test evidence. Minor platform-font and generated-texture differences are accepted P3 differences from the static mock.

## Implementation checklist

- [x] Match the selected editorial layout in both languages.
- [x] Use the real app renders and preserve their complete frame.
- [x] Verify scrolling, direct selection, keyboard use and reduced motion.
- [x] Verify one primary action and direct release downloads.
- [x] Compare revised browser captures against the source image.

final result: passed
