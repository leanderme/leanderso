# Health Push

A one-screen iPhone app that sends daily Apple Health summaries for the last 30 days to the website. It posts the `repository_dispatch` payload described in `docs/live-data.md`, so `.github/workflows/health.yml` records it and Vercel redeploys.

## What it sends

Daily totals for the last 30 complete days, every time: steps, walking and running distance, active energy, exercise minutes, workouts (count and minutes per type), resting heart rate, heart rate variability and VO₂ max, plus minutes asleep for the night that ended the following morning (18:00 to 12:00, asleep stages only). It uses one HealthKit statistics collection per metric, so iPhone and Apple Watch samples are not counted twice, and it merges overlapping sleep samples from different sources. Figures with no data are left out. Sending 30 days each time fills any gaps and corrects days the Watch synced late; the payload is about 5 KB.

"Found in Apple Health" lists, for each metric, how many of the last 30 days had data, refreshed on every send or with "Check Apple Health now". iOS returns nothing, rather than an error, for a type you didn't allow, so a metric at 0 days usually means its switch is off in Settings → Health → Data Access & Devices.

## When it sends

Once a day, at the first opportunity after 09:00:

- when you open the app,
- when HealthKit wakes it in the background because new steps or sleep arrived (background delivery, at most hourly),
- from a background refresh scheduled for about 09:15.

iOS decides when background work actually runs and keeps Health data unreadable while the phone is locked, so on some days the summary goes out later, typically the next time you unlock the phone. "Send the last 30 days now" always sends immediately and replaces those days on the site.

## Install

1. Create the fine-grained GitHub token described in `docs/live-data.md` (only `leanderme/leanderso`, Contents read and write).
2. Open `ios/HealthPush.xcodeproj` in Xcode. Under Signing & Capabilities, check the team. The project uses Leander Melms (`68V5ZWC7U9`), the paid Individual membership of leander.melms@gmx.de, so a build stays valid for a year and can go to TestFlight.
3. Connect the iPhone, choose it as the run destination, select the Release configuration under Product → Scheme → Edit Scheme → Run, and run. Release builds hide the testing tools and don't ask for permission to write Health data.
4. In the app: Allow Health access (turn on all types), paste the token, Save, then "Send the last 30 days now". The Actions tab should show a Health run, and `data/health.json` should get a commit.

To change access later: Settings → Health → Data Access & Devices → Health Push. To stop sending, remove the token in the app or revoke it on GitHub.

## TestFlight

One-time setup in App Store Connect → Apps → New App: platform iOS, bundle ID `so.leander.healthpush`, any SKU (for example `healthpush`). The record exists as "Health Push for leander.so" (Apple ID 6831673523), with an internal TestFlight group "Leander" that receives new Xcode builds automatically. Internal testers need no beta review.

Then, for every new build:

```sh
ios/testflight.sh
```

It archives a Release build with the current UTC time as build number and uploads it with the Apple ID signed into Xcode. App Store Connect usually needs 5 to 15 minutes to process a build before it shows up in the TestFlight app.

## Testing in the Simulator

Debug builds add a Testing section with "Add 30 days of sample data", which writes steps, overlapping sleep stages and workouts to the Simulator's Health store. Over the last 7 days the site should then show 8,200 steps a day, 42 km, 450 kcal a day, 6 workouts (running 160 min, strength 70 min), 7:30 sleep, 52 ms HRV and a VO₂ max of 45.2.

To keep test data away from the real site, point the app at a local server:

```sh
xcrun simctl install booted <path to HealthPush.app>
SIMCTL_CHILD_HEALTHPUSH_API_BASE=http://localhost:8787 xcrun simctl launch booted so.leander.healthpush
```

Any server on port 8787 that answers `POST /repos/leanderme/leanderso/dispatches` with 204 will do. The "Sends to" row shows which host the app is using.
