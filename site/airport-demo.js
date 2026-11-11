import { airports } from "./airport-data.js";
import { createBoardTransition } from "./board-transition.js";

export function initAirportPreview() {
  const hero = document.querySelector(".airport-hero");
  const image = document.querySelector("#airport-board");
  const stage = document.querySelector("#airport-expand");
  const choices = [...document.querySelectorAll('input[name="airport"]')];
  const letters = [...document.querySelectorAll(".flap-letter")];
  const status = document.querySelector("#airport-status");
  const date = document.querySelector("#local-date");
  const dialog = document.querySelector("#airport-dialog");
  const zoomImage = document.querySelector("#airport-zoom");
  const close = document.querySelector("#airport-close");
  const korean = document.documentElement.lang === "ko";
  const sampleLabel = korean ? "샘플 화면" : "Sample preview";
  const failureLabel = korean
    ? "미리보기를 불러오지 못했습니다. 공항을 다시 골라주세요."
    : "The preview could not load. Select an airport to retry.";
  const motion =
    typeof matchMedia === "function"
      ? matchMedia("(prefers-reduced-motion: reduce)")
      : null;
  const isReducedMotion = () => (motion ? motion.matches : true);
  const transition = createBoardTransition(stage, isReducedMotion);
  const events = new AbortController();
  let current = airports.findIndex(
    (airport) => image.getAttribute("src") === airport.image,
  );
  let generation = 0;
  let disposed = false;
  let frame;
  let scrollStage = 0;
  let reveal;
  let letterAnimations = [];

  if (current < 0) current = 0;
  const today = new Date();
  const localDate = [
    today.getFullYear(),
    String(today.getMonth() + 1).padStart(2, "0"),
    String(today.getDate()).padStart(2, "0"),
  ].join("-");
  date.dateTime = localDate;
  date.textContent = localDate;

  function updateControls(index) {
    for (const choice of choices)
      choice.checked = choice.value === airports[index].code;
    for (const [position, letter] of letters.entries())
      letter.textContent = airports[index].code[position];
  }

  function cancelTransition() {
    transition.cancel();
    for (const animation of letterAnimations) animation.cancel();
    letterAnimations = [];
  }

  async function animateCode(code) {
    for (const [position, letter] of letters.entries()) {
      letter.textContent = code[position];
      if (isReducedMotion() || typeof letter.animate !== "function") continue;
      letterAnimations.push(
        letter.animate(
          [
            { transform: "scaleX(.84) rotateX(-90deg)", opacity: 0 },
            { transform: "scaleX(.84) rotateX(0deg)", opacity: 1 },
          ],
          {
            duration: 520,
            delay: position * 90,
            easing: "cubic-bezier(.2,.7,.25,1)",
            fill: "both",
          },
        ),
      );
    }
    await Promise.all(
      letterAnimations.map((animation) => animation.finished.catch(() => {})),
    );
  }

  async function updateAirport(index, token) {
    const airport = airports[index];
    const next = new Image();
    next.srcset = airport.srcSet;
    next.sizes = image.sizes;
    next.src = airport.image;
    await next.decode();
    if (disposed || token !== generation) return;
    for (const choice of choices)
      choice.checked = choice.value === airport.code;
    if (current !== index)
      await Promise.all([transition.play(next), animateCode(airport.code)]);
    if (disposed || token !== generation) return;
    current = index;
    image.srcset = airport.srcSet;
    image.src = airport.image;
    image.alt = `${korean ? airport.name : airport.nameEn} · ${sampleLabel}`;
    cancelTransition();
    updateControls(current);
    status.textContent = `${airport.code} · ${sampleLabel}`;
  }

  function requestAirport(index) {
    if (index < 0 || index >= airports.length) return;
    const token = ++generation;
    cancelTransition();
    updateControls(current);
    stage.setAttribute("aria-busy", "true");
    updateAirport(index, token)
      .catch((error) => {
        if (disposed || token !== generation) return;
        updateControls(current);
        status.textContent = failureLabel;
        console.error(
          "Airport preview failed",
          error instanceof Error ? error.message : "Unknown image error",
        );
      })
      .finally(() => {
        if (token === generation) stage.removeAttribute("aria-busy");
      });
  }

  function onScroll() {
    if (frame || isReducedMotion() || dialog.open) return;
    frame = requestAnimationFrame(() => {
      frame = undefined;
      const rect = hero.getBoundingClientRect();
      const viewport = document.documentElement;
      const pinned = viewport.clientWidth > 900;
      const travel = pinned
        ? hero.offsetHeight - viewport.clientHeight
        : hero.offsetHeight * 0.65;
      const amount = Math.max(0, Math.min(1, -rect.top / Math.max(1, travel)));
      const nextStage = Math.min(2, Math.floor(amount * 3));
      if (nextStage !== scrollStage && rect.bottom > 0 && rect.top <= 0) {
        scrollStage = nextStage;
        requestAirport(nextStage);
      }
    });
  }

  function onSelect(event) {
    requestAirport(
      airports.findIndex((airport) => airport.code === event.target.value),
    );
  }

  function onEnvironmentChange() {
    generation++;
    cancelTransition();
    stage.removeAttribute("aria-busy");
    updateControls(current);
    onScroll();
  }

  function onExpand() {
    zoomImage.src = image.src;
    zoomImage.alt = image.alt;
    if (typeof dialog.showModal !== "function") {
      window.open(image.src, "_blank", "noopener");
      return;
    }
    dialog.showModal();
    document.body.classList.add("demo-dialog-open");
  }

  function onClose() {
    dialog.close();
  }

  function onDismiss() {
    document.body.classList.remove("demo-dialog-open");
  }

  function onBackdrop(event) {
    if (event.target === dialog) dialog.close();
  }

  function listen(target, name, callback, options = {}) {
    target.addEventListener(name, callback, {
      ...options,
      signal: events.signal,
    });
  }
  for (const choice of choices) listen(choice, "change", onSelect);
  listen(window, "scroll", onScroll, { passive: true });
  listen(window, "resize", onEnvironmentChange, { passive: true });
  listen(stage, "click", onExpand);
  listen(close, "click", onClose);
  listen(dialog, "close", onDismiss);
  listen(dialog, "click", onBackdrop);
  if (motion && typeof motion.addEventListener === "function")
    listen(motion, "change", onEnvironmentChange);

  if (typeof IntersectionObserver === "function" && !isReducedMotion()) {
    reveal = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            reveal.unobserve(entry.target);
          }
        }
      },
      { threshold: 0.1 },
    );
    for (const section of document.querySelectorAll(".section")) {
      section.classList.add("reveal-ready");
      reveal.observe(section);
    }
  }

  function dispose() {
    disposed = true;
    generation++;
    cancelAnimationFrame(frame);
    cancelTransition();
    stage.removeAttribute("aria-busy");
    events.abort();
    if (reveal) reveal.disconnect();
    document.body.classList.remove("demo-dialog-open");
  }
  listen(window, "pagehide", dispose, { once: true });
  updateControls(current);
  onScroll();
  return dispose;
}
