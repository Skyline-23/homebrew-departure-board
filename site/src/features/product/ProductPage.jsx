import copy from "@/features/product/copy.json";
import site from "@/generated/site.json";
import Enhancements from "@/features/product/Enhancements";

const release =
  "https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/";
const boardSizes =
  "(max-width: 900px) calc(100vw - 40px), (max-width: 1680px) 65vw, 1140px";

export default function ProductPage({ language }) {
  const text = copy[language];
  const korean = language === "ko";
  const guide = `/guide/${korean ? "ko" : "index"}.html`;
  const firstAirport = site.airports[0];
  const date = new Date().toISOString().slice(0, 10);
  return (
    <>
      <header className="site-header">
        <a className="brand" href={korean ? "/ko.html" : "/"}>
          <img src={site.icon} alt="" width="32" height="32" />
          Departure Board
        </a>
        <nav aria-label={korean ? "사이트 메뉴" : "Site navigation"}>
          <a className="nav-guide" href={guide}>
            {text.navGuide}
          </a>
          <a className="nav-install" data-download href="/download">
            {text.navInstall}
          </a>
          <a
            className="language-link"
            href={korean ? "/" : "/ko.html"}
            lang={korean ? "en" : "ko"}
          >
            {text.languageLabel}
          </a>
        </nav>
      </header>
      <main>
        <section className="airport-hero" aria-label={text.enlarge}>
          <div className="hero-scene">
            <div className="hero-intro">
              <div className="hero-copy">
                <h1>
                  {text.heroTitle[0]}
                  <br />
                  {text.heroTitle[1]}
                </h1>
                <p>{text.subtitle}</p>
              </div>
              <div className="airport-index">
                <div className="airport-identity">
                  <p className="index-label">
                    DEPARTURE
                    <br />
                    BOARD
                  </p>
                  <div className="flap-code" aria-hidden="true">
                    {[..."ICN"].map((letter, index) => (
                      <span className="flap-tile" key={index}>
                        <span className="flap-letter">{letter}</span>
                      </span>
                    ))}
                  </div>
                </div>
                <fieldset className="airport-route">
                  <legend className="visually-hidden">
                    {text.chooseAirport}
                  </legend>
                  {site.airports.map((airport, index) => (
                    <label className="airport-stop" key={airport.code}>
                      <input
                        type="radio"
                        name="airport"
                        value={airport.code}
                        aria-label={text.airportLabels[index]}
                        defaultChecked={index === 0}
                      />
                      <span>{airport.code}</span>
                    </label>
                  ))}
                </fieldset>
              </div>
            </div>
            <div className="hero-preview">
              <div className="hero-aside">
                <div className="hero-download">
                  <a className="button" data-download href="/download">
                    <span>{text.get}</span>
                    <img src="/arrow-right.svg" width="32" height="32" alt="" />
                  </a>
                  <p className="download-note" data-detected-platform>
                    {text.installerNote}
                  </p>
                  <details className="platform-picker">
                    <summary>{text.platformQuestion}</summary>
                    <div className="platform-options">
                      <a href={`${release}DepartureBoard-universal.dmg`}>
                        macOS · Apple Silicon / Intel
                      </a>
                      <a href={`${release}DepartureBoard-win-x64-Setup.exe`}>
                        Windows · Intel / AMD (x64)
                      </a>
                      <a href={`${release}DepartureBoard-win-arm64-Setup.exe`}>
                        Windows · ARM64
                      </a>
                    </div>
                  </details>
                </div>
                <div className="preview-caption">
                  <p id="airport-status" className="demo-status" role="status">
                    ICN · {text.sampleLabel}
                  </p>
                  <time id="local-date" dateTime={date}>
                    {date}
                  </time>
                </div>
              </div>
              <button
                id="airport-expand"
                className="board-expand"
                aria-label={text.enlarge}
                aria-haspopup="dialog"
              >
                <img
                  id="airport-board"
                  className="board-image"
                  src={firstAirport.image}
                  srcSet={firstAirport.srcSet}
                  sizes={boardSizes}
                  width="1920"
                  height="1080"
                  alt={`${korean ? firstAirport.name : firstAirport.nameEn} · ${text.sampleLabel}`}
                  fetchPriority="high"
                />
              </button>
            </div>
          </div>
        </section>
        <dialog
          className="board-dialog"
          id="airport-dialog"
          aria-label={text.dialogLabel}
        >
          <div className="dialog-toolbar">
            <span>{text.dialogHint}</span>
            <button id="airport-close" type="button">
              {text.close}
            </button>
          </div>
          <div className="dialog-image-wrap">
            <img
              className="board-zoom"
              id="airport-zoom"
              alt=""
              width="1920"
              height="1080"
            />
          </div>
        </dialog>
        <section className="section" id="features">
          <h2>{text.featuresTitle}</h2>
          <div className="features">
            {text.features.map((item) => (
              <article key={item.title}>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
          </div>
        </section>
        <section className="section">
          <h2>{text.settingsTitle}</h2>
          <p>{text.settingsBody}</p>
          <div className="settings">
            {["macos-settings.png", "windows-settings.png"].map(
              (filename, index) => {
                const image = site.images[filename];
                return (
                  <figure
                    className={index === 0 ? "mac" : undefined}
                    key={filename}
                  >
                    <picture>
                      <source
                        type="image/webp"
                        srcSet={image.srcSet}
                        sizes="(max-width: 700px) calc(100vw - 80px), 400px"
                      />
                      <img
                        src={image.src}
                        width={image.width}
                        height={image.height}
                        alt={text.settingsLabels[index]}
                        loading="lazy"
                        decoding="async"
                      />
                    </picture>
                    <figcaption>{text.settingsLabels[index]}</figcaption>
                  </figure>
                );
              },
            )}
          </div>
        </section>
        <section className="section">
          <h2>{text.faqTitle}</h2>
          {text.faq.map((item) => (
            <details key={item.title}>
              <summary>{item.title}</summary>
              <p>{item.body}</p>
            </details>
          ))}
        </section>
      </main>
      <footer id="download">
        <span>{text.credit}</span>
        <div>
          <a href={guide}>{text.navGuide}</a>
          <a
            href={`https://portfolio.skyline23.com/${language}/projects/departure-board`}
          >
            {text.portfolioLabel}
          </a>
          <a href="https://github.com/Skyline-23/homebrew-departure-board">
            GitHub
          </a>
          <a href="https://blog.skyline23.com">Blog</a>
        </div>
      </footer>
      <Enhancements previewFailure={text.previewFailure} />
    </>
  );
}
