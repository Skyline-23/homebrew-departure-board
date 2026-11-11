"use client";

import { useEffect } from "react";
import { initDownloads } from "@/features/product/download.js";

export default function Enhancements({ previewFailure }) {
  useEffect(() => {
    const releaseDownloads = initDownloads();
    let releasePreview;
    let active = true;
    async function startPreview() {
      try {
        const { initAirportPreview } =
          await import("@/features/product/airport-demo.js");
        if (active) releasePreview = initAirportPreview();
      } catch {
        if (!active) return;
        const status = document.querySelector("#airport-status");
        if (status) {
          status.textContent = previewFailure;
        }
        console.error("Airport preview initialization failed.");
      }
    }
    startPreview();
    function restore(event) {
      if (event.persisted) {
        releasePreview?.();
        startPreview();
      }
    }
    window.addEventListener("pageshow", restore);
    return () => {
      active = false;
      releaseDownloads();
      releasePreview?.();
      window.removeEventListener("pageshow", restore);
    };
  }, [previewFailure]);
  return null;
}
