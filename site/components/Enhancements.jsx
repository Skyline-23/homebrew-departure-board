"use client";

import { useEffect } from "react";
import { initDownloads } from "../download.js";

export default function Enhancements() {
  useEffect(() => {
    const releaseDownloads = initDownloads();
    let releasePreview;
    let active = true;
    import("../airport-demo.js").then(({ initAirportPreview }) => {
      if (active) releasePreview = initAirportPreview();
    });
    function restore(event) {
      if (event.persisted) {
        releasePreview?.();
        import("../airport-demo.js").then(({ initAirportPreview }) => {
          if (active) releasePreview = initAirportPreview();
        });
      }
    }
    window.addEventListener("pageshow", restore);
    return () => {
      active = false;
      releaseDownloads();
      releasePreview?.();
      window.removeEventListener("pageshow", restore);
    };
  }, []);
  return null;
}
