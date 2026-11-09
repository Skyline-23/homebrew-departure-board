# AeroDataBox API key setup

**[English](api-key.md) · [한국어](api-key.ko.md) · [Back to README](../README.md)**

Departure Board uses the **RapidAPI version of AeroDataBox**. Choose that subscription channel: an AeroDataBox direct-subscription key uses a different gateway and does not work in this app.

## 1. Create a RapidAPI account

Sign up or sign in at [RapidAPI](https://rapidapi.com/). RapidAPI normally creates a default app for your account. You can use it or create a separate app named **Departure Board** in the [Developer Dashboard](https://rapidapi.com/developer/dashboard).

## 2. Subscribe to AeroDataBox

Open the official [AeroDataBox pricing page](https://rapidapi.com/aedbx-aedbx/api/aerodatabox/pricing), choose a plan and complete the subscription.

- Account registration and API subscription are separate steps.
- A free Basic plan is listed, with a monthly allowance. It is not an unlimited live feed.
- RapidAPI may request billing details for a free plan. Check the price, allowance, possible charges and applicable terms shown before confirming.
- Choose a refresh interval that fits your plan. The app's **Refresh interval** setting controls network polling; language, page and codeshare rotation do not consume extra requests.

Plans can change. Use the [current pricing page](https://rapidapi.com/aedbx-aedbx/api/aerodatabox/pricing) for the latest limits. If you publish flight-data screenshots, also check the provider's [attribution terms](https://aerodatabox.com/2026-09-terms-update/).

## 3. Find or create the key

1. Open the [Developer Dashboard](https://rapidapi.com/developer/dashboard).
2. Go to **Apps** and select your default app or **Departure Board**.
3. Open **Authorization** and copy an existing app key. If you need a new one, select **Add authorization** and give it a name.
4. The value you need is **X-RapidAPI-Key**. You can also find it in the code snippet on AeroDataBox's **Endpoints** tab.

Copy only the key value. **X-RapidAPI-Host**, the app ID and your account password are different values; the app already supplies the host.

## 4. Save it in Departure Board

1. Open **Departure Board** from `/Applications` or its menu bar icon, then open **Settings**.
2. Set **Timetable source** to **Live flight data**.
3. Paste the key into **API key** and select **Apply**.
4. Choose an airport and allow the first refresh to finish.

The key is stored in macOS Keychain and shown as a masked value after saving. App, wallpaper and screen saver use the same settings; you do not need a separate key for each airport or monitor.

## If flight data does not appear

| What you see | What to check |
| --- | --- |
| Authentication error / 401 | Copy the complete RapidAPI app key again and confirm that it is still active. |
| Subscription or access error / 403 | Confirm that AeroDataBox is subscribed under the same account. Check airport coverage and plan access. |
| API limit reached / 429 | Review usage in RapidAPI and increase the refresh interval or wait for the provider's retry window. |
| Sample flights | Change **Timetable source** from **Sample schedule** to **Live flight data**. |
| No departures for one airport | Data coverage and the available departure window vary. This does not necessarily mean that the key is invalid. |

Do not include API keys in issues, screenshots or shared configuration files. If a key is exposed, create a replacement in **Authorization**, update the app and revoke the old key.

Sources: [RapidAPI key management](https://docs.rapidapi.com/v2/docs/keys-and-key-rotation), [RapidAPI subscription guide](https://docs.rapidapi.com/v2/docs/api-pricing), [AeroDataBox API documentation](https://doc.aerodatabox.com/rapidapi.html).
