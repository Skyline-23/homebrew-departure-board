import { AIRPORTS } from "./airports.js";
import { normalizeDepartures } from "./normalize.js";

function json(body, status = 200) {
  return Response.json(body, { status, headers: { "Cache-Control": "private, no-store" } });
}

function tokenMatches(provided, expected) {
  if (!provided || !expected || provided.length !== expected.length) return false;
  let mismatch = 0;
  for (let index = 0; index < expected.length; index++) {
    mismatch |= provided.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return mismatch === 0;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ service: "departure-board", ready: Boolean(env.AERODATABOX_API_KEY) });
    if (request.method !== "GET") return json({ error: "Method not allowed" }, 405);
    const code = url.pathname.match(/^\/v1\/departures\/([A-Z]{3})$/)?.[1];
    if (!code || !AIRPORTS.has(code)) return json({ error: "Unsupported airport" }, 404);
    const token = request.headers.get("Authorization")?.replace(/^Bearer /, "");
    if (!tokenMatches(token, env.BOARD_ACCESS_TOKEN)) return json({ error: "Unauthorized" }, 401);
    if (!env.AERODATABOX_API_KEY) return json({ error: "Flight provider is not configured" }, 503);
    const cache = env.AIRPORT_CACHE.get(env.AIRPORT_CACHE.idFromName("shared-budget"));
    return cache.fetch(new Request(`https://cache.internal/${code}`));
  },
};

export class AirportCache {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    // One object owns both cache misses and the daily allowance, preventing a
    // burst of clients from issuing duplicate paid upstream requests.
    return this.state.blockConcurrencyWhile(async () => {
      const code = new URL(request.url).pathname.slice(1);
      if (!AIRPORTS.has(code)) return json({ error: "Unsupported airport" }, 404);
      const now = Date.now();
      const cached = await this.state.storage.get(`airport:${code}`);
      const age = cached ? now - Date.parse(cached.fetchedAt) : Infinity;
      const ttl = Math.max(300, Number(this.env.CACHE_SECONDS) || 900) * 1000;
      if (age < ttl) return json(cached);

      const day = new Date(now).toISOString().slice(0, 10);
      const budget = (await this.state.storage.get("budget")) ?? { day, used: 0 };
      if (budget.day !== day) { budget.day = day; budget.used = 0; }
      const maximum = Math.max(1, Number(this.env.DAILY_REQUEST_LIMIT) || 4);
      if (budget.used >= maximum) {
        return age < 7 * 86400000
          ? json({ ...cached, stale: true, reason: "Daily request allowance reached" })
          : json({ error: "Daily request allowance reached" }, 429);
      }
      budget.used += 1;
      await this.state.storage.put("budget", budget);

      const endpoint = new URL(`https://aerodatabox.p.rapidapi.com/flights/airports/iata/${code}`);
      endpoint.search = new URLSearchParams({
        offsetMinutes: "-30", durationMinutes: "360", direction: "Departure",
        withLeg: "true", withCancelled: "true", withCodeshared: "false",
        withCargo: "false", withPrivate: "false", withLocation: "false",
      });
      let response;
      try {
        response = await fetch(endpoint, {
          headers: { "X-RapidAPI-Key": this.env.AERODATABOX_API_KEY, "X-RapidAPI-Host": "aerodatabox.p.rapidapi.com" },
          signal: AbortSignal.timeout(20000),
        });
      } catch {
        return age < 7 * 86400000
          ? json({ ...cached, stale: true, reason: "Provider temporarily unavailable" })
          : json({ error: "Provider temporarily unavailable" }, 502);
      }
      if (!response.ok) {
        return age < 7 * 86400000
          ? json({ ...cached, stale: true, reason: "Provider request failed" })
          : json({ error: "Provider request failed", providerStatus: response.status }, 502);
      }
      let payload;
      try { payload = await response.json(); } catch { return json({ error: "Invalid provider response" }, 502); }
      const normalized = normalizeDepartures(payload, code);
      await this.state.storage.put(`airport:${code}`, normalized);
      return json(normalized);
    });
  }
}
