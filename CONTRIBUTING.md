# Contributing

Departure Board currently supports macOS 12 and later. A Windows version is
planned for a later release; no Windows build is available yet.

## Build and check

Install Xcode command-line tools and Python 3, then run:

```sh
./script/build.sh
./script/validate.sh
```

Builds stay in `work/Build.noindex`. The validation command checks data,
translations, installation and rendering, and exports all 44 visual profiles.
Window lifecycle tests run in GitHub Actions. To run them deliberately on your
own Mac, set `RUN_INTERACTIVE_TESTS=1`; they open and close test windows.

## Making a change

- Keep source code and settings text in English. Put visible board text in
  `Resources/<language>.lproj/Localizable.strings`.
- Keep airport-specific layout data in `Resources/Locations`. Include the source
  photograph or official reference when changing a profile.
- Keep drawing independent of network requests. The app fetches flight data;
  the screen saver reads the shared cache.
- Preserve a single row for codeshares, local time zones, language rotation and
  missing-data states. Do not invent operational data when the provider omits it.
- Keep caches bounded and skip work when nothing visible has changed. Describe
  the measurement and test conditions for performance changes.
- Include before/after images for visual changes and focused regression checks
  for behavior changes. Do not rewrite unrelated files or refresh the entire
  logo collection for a small fix.

In your pull request, explain the problem, the resulting behavior and the checks
that passed. Never include API keys, Keychain exports or personal flight caches.

Project code is MIT-licensed. Read [third-party notices](THIRD_PARTY_NOTICES.md)
before copying or replacing airline artwork or upstream data.
