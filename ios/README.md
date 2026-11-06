# Health Push

A one-screen iPhone app that sends yesterday's Apple Health summary to the website. It posts the same `repository_dispatch` payload as the iOS Shortcut described in `docs/live-data.md`, so `.github/workflows/health.yml` records it and Vercel redeploys.

## What it sends

For the previous calendar day: steps, exercise minutes, resting heart rate and number of workouts, plus minutes asleep for the night that ended that morning (18:00 to 12:00, asleep stages only). It uses HealthKit statistics queries, so iPhone and Apple Watch steps are not counted twice, and it merges overlapping sleep samples from different sources. Figures with no data are left out.

## When it sends

Once a day, at the first opportunity after 09:00:

- when you open the app,
- when HealthKit wakes it in the background because new steps or sleep arrived (background delivery, at most hourly),
- from a background refresh scheduled for about 09:15.

iOS decides when background work actually runs and keeps Health data unreadable while the phone is locked, so on some days the summary goes out later, typically the next time you unlock the phone. "Send yesterday's summary now" always sends immediately and replaces that day's figures if it was already sent.

## Install

1. Create the fine-grained GitHub token described in `docs/live-data.md` (only `leanderme/leanderso`, Contents read and write).
2. Open `ios/HealthPush.xcodeproj` in Xcode. Under Signing & Capabilities, check the team. The project uses Leander Melms (`68V5ZWC7U9`), the paid Individual membership of leander.melms@gmx.de, so a build stays valid for a year and can go to TestFlight.
3. Connect the iPhone, choose it as the run destination, select the Release configuration under Product → Scheme → Edit Scheme → Run, and run. Release builds hide the testing tools and don't ask for permission to write Health data.
4. In the app: Allow Health access (turn on all five types), paste the token, Save, then "Send yesterday's summary now". The Actions tab should show a Health run, and `data/health.json` should get a commit.

To change access later: Settings → Health → Data Access & Devices → Health Push. To stop sending, remove the token in the app or revoke it on GitHub.

## TestFlight

One-time setup in App Store Connect → Apps → New App: platform iOS, bundle ID `so.leander.healthpush`, any SKU (for example `healthpush`). The record exists as "Health Push for leander.so" (Apple ID 6831673523), with an internal TestFlight group "Leander" that receives new Xcode builds automatically. Internal testers need no beta review.

Then, for every new build:

```sh
ios/testflight.sh
```

It archives a Release build with the current UTC time as build number and uploads it with the Apple ID signed into Xcode. App Store Connect usually needs 5 to 15 minutes to process a build before it shows up in the TestFlight app.

## Testing in the Simulator

Debug builds add a Testing section with "Add 30 days of sample data", which writes steps, overlapping sleep stages and workouts to the Simulator's Health store. Yesterday then reads 8,050 steps, 7 h 30 min of sleep and 1 workout.

To keep test data away from the real site, point the app at a local server:

```sh
xcrun simctl install booted <path to HealthPush.app>
SIMCTL_CHILD_HEALTHPUSH_API_BASE=http://localhost:8787 xcrun simctl launch booted so.leander.healthpush
```

Any server on port 8787 that answers `POST /repos/leanderme/leanderso/dispatches` with 204 will do. The "Sends to" row shows which host the app is using.
