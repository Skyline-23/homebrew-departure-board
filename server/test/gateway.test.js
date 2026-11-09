import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { AirportCache } from "../src/index.js";
import { normalizeDepartures } from "../src/normalize.js";

test("normalizes departures, removes duplicates and retains unavailable gates as empty", () => {
  const flight = { number: "KE 703", status: "Boarding", departure: { scheduledTime: { utc: "2026-11-09T03:00:00Z", local: "2026-11-09T12:00:00+09:00" } }, arrival: { airport: { iata: "NRT", municipalityName: "Tokyo" } } };
  const result = normalizeDepartures({ departures: [flight, flight, { number: "bad" }] }, "ICN");
  assert.equal(result.flights.length, 1);
  assert.equal(result.flights[0].destinationCode, "NRT");
  assert.equal(result.flights[0].gate, "");
});

test("rejects an unauthenticated request before touching the provider", async () => {
  const response = await worker.fetch(new Request("https://example.test/v1/departures/ICN"), { BOARD_ACCESS_TOKEN: "secret" });
  assert.equal(response.status, 401);
});

test("converts provider timestamps with spaces into ISO timestamps for macOS", () => {
  const result = normalizeDepartures({ departures: [{
    number: "UL 471",
    departure: {
      scheduledTime: { utc: "2026-11-09 02:35Z" },
      revisedTime: { utc: "2026-11-09 03:55Z" },
    },
  }] }, "ICN");
  assert.equal(result.flights[0].scheduledUtc, "2026-11-09T02:35:00.000Z");
  assert.equal(result.flights[0].revisedUtc, "2026-11-09T03:55:00.000Z");
});

test("rejects arbitrary upstream targets", async () => {
  const response = await worker.fetch(new Request("https://example.test/v1/departures/XYZ"), {});
  assert.equal(response.status, 404);
});

test("enforces the shared daily request budget without invoking upstream fetch", async () => {
  const storage = new Map([["budget", { day: new Date().toISOString().slice(0, 10), used: 4 }]]);
  const cache = new AirportCache({ storage: { get: async key => storage.get(key), put: async (key, value) => storage.set(key, value) }, blockConcurrencyWhile: action => action() }, { DAILY_REQUEST_LIMIT: "4" });
  const response = await cache.fetch(new Request("https://internal/ICN"));
  assert.equal(response.status, 429);
});

test("returns a cached snapshot without consuming a provider request", async () => {
  const value = { airport: "ICN", fetchedAt: new Date(Date.now() - 5 * 3600000).toISOString(), flights: [] };
  const cache = new AirportCache({ storage: { get: async key => key === "airport:v2:ICN" ? value : undefined }, blockConcurrencyWhile: action => action() }, {});
  assert.deepEqual(await (await cache.fetch(new Request("https://internal/ICN"))).json(), value);
});
