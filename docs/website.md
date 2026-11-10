# Product website

The portfolio landing page is `https://portfolio.skyline23.com/ko/projects/departure-board`.
The detailed product site is `https://dpboard.skyline23.com`, hosted by the Cloudflare Pages project `departure-board`.
The existing apex domain, blog and portfolio deployments are separate.

Build the static site with Python 3:

```sh
python3 script/build-guide.py --check
python3 script/build-site.py
```

The output is `work/site`. The build copies the same English/Korean illustrated guide that ships inside the apps. The build reads a release label from `Casks/departure-board.rb`; `--version 0.7.3` can prepare the next release. Download redirects always use GitHub `releases/latest/download/...` and stable asset names, so they automatically follow the newest published release without a site rebuild. The page makes no flight-provider requests or runtime GitHub API calls.

Cloudflare Pages is connected to this repository, with `main` as the production branch, `python3 script/build-site.py` as the build command and `work/site` as the output directory. Every published release includes the stable `DepartureBoard-universal.zip` filename alongside its versioned macOS archive. Windows archives already use stable x64 and ARM64 filenames. No additional browser-side release polling is needed.

For a local preview:

```sh
python3 -m http.server 8766 --directory work/site
```

Python's local server does not process Pages `_redirects` or `_headers`; verify downloads and response headers on the Pages preview URL before production deployment.
