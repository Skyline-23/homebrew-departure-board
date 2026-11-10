const TRANSITION_DURATION_MS = 360;
const ROW_DELAY_MS = 17;

export function createBoardTransition(stage, prefersReducedMotion) {
  let layer;
  let animations = [];

  function cancel() {
    for (const animation of animations) animation.cancel();
    animations = [];
    if (layer) layer.remove();
    layer = undefined;
  }

  async function play(nextImage) {
    cancel();
    const canAnimate = typeof stage.animate === "function";
    if (prefersReducedMotion() || !canAnimate) return;

    const scale = Math.min(
      stage.clientWidth / nextImage.naturalWidth,
      stage.clientHeight / nextImage.naturalHeight,
    );
    const width = nextImage.naturalWidth * scale;
    const height = nextImage.naturalHeight * scale;
    const rowCount = stage.clientWidth < 700 ? 14 : 24;
    const nextLayer = document.createElement("div");
    nextLayer.className = "board-flip";
    nextLayer.setAttribute("aria-hidden", "true");
    Object.assign(nextLayer.style, {
      width: `${width}px`,
      height: `${height}px`,
      left: `${(stage.clientWidth - width) / 2}px`,
      top: `${(stage.clientHeight - height) / 2}px`,
    });
    layer = nextLayer;
    stage.append(nextLayer);

    for (let row = 0; row < rowCount; row++) {
      const strip = document.createElement("div");
      strip.className = "flip-strip";
      Object.assign(strip.style, {
        top: `${(row * height) / rowCount}px`,
        height: `${height / rowCount + 1}px`,
        backgroundImage: `url("${nextImage.src}")`,
        backgroundSize: `${width}px ${height}px`,
        backgroundPosition: `0 -${(row * height) / rowCount}px`,
      });
      nextLayer.append(strip);
      animations.push(
        strip.animate(
          [
            { transform: "rotateX(-88deg)", opacity: 0 },
            { transform: "rotateX(0deg)", opacity: 1 },
          ],
          {
            duration: TRANSITION_DURATION_MS,
            delay: row * ROW_DELAY_MS,
            easing: "cubic-bezier(.2,.7,.25,1)",
            fill: "both",
          },
        ),
      );
    }
    await Promise.all(
      animations.map((animation) => animation.finished.catch(() => {})),
    );
  }

  return { play, cancel };
}
