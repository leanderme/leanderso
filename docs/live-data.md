# Live data on the homepage

The homepage stays a static site. Data is committed to `data/` by GitHub Actions, and each commit to `main` makes Vercel rebuild the site. Visitors' browsers never contact GitHub, Apple or any other service.

| Section | Source | How it updates | File |
| --- | --- | --- | --- |
| Code | GitHub contribution calendar | `.github/workflows/github-activity.yml`, daily at 04:23 UTC | `data/github.json` |
| Health | Apple Health on Leander's iPhone | Health Push app (`ios/`) or an iOS Shortcut → `.github/workflows/health.yml` | `data/health.json` |

Both workflows commit as `leanderme` with the GitHub noreply address, so Vercel deploys their commits like any other push. They share a concurrency group, so they never push at the same time.

## GitHub activity

`scripts/fetch-github.mjs` queries the GraphQL API with the workflow's built-in `GITHUB_TOKEN`. The public profile already includes private contribution counts (3,734 in the year to 6 November 2026, matching the logged-in total), so no personal token is needed. Only daily counts are stored, never repository names.

Run it by hand from the Actions tab (GitHub activity → Run workflow), or locally:

```sh
GITHUB_TOKEN=$(gh auth token) node scripts/fetch-github.mjs
```

## Apple Health

Apple Health has no web API, so the iPhone sends the figures. The recommended sender is the Health Push app in `ios/` (see `ios/README.md`): each morning it sends daily totals for the last 30 complete days, read with deduplicated HealthKit statistics, and it can send in the background. Resending earlier days fills gaps and picks up data the Watch synced late; days that haven't changed produce no commit. An iOS Shortcut is described below as a fallback. Either one posts a `repository_dispatch` event, and `scripts/record-health.mjs` checks every value against a plausible range before storing it. Only daily totals are kept, for the last 120 days.

The Health section appears once there is data and hides itself when the newest day is more than 10 days old (`site.health.staleAfterDays`), so a broken sender never leaves stale figures on the page. Averages and totals cover the last seven days that have data; with less history, the note under the figures says how many days they cover.

### Payload

```json
{
  "event_type": "health",
  "client_payload": {
    "days": [
      {
        "date": "2026-11-05",
        "steps": 8432,
        "distanceMeters": 6120,
        "activeEnergy": 455,
        "exerciseMinutes": 42,
        "workouts": 2,
        "workoutMinutes": { "running": 40, "strength": 35 },
        "sleepMinutes": 431,
        "restingHeartRate": 54,
        "hrv": 48,
        "vo2Max": 45.2
      }
    ]
  }
}
```

A single day without the `days` wrapper is also accepted, which is what the Shortcut sends. Each day needs a `date` within the last 40 days; every other field is optional, and a figure that's missing is skipped. A day that's sent again replaces the stored one. Numbers may arrive as strings, including with a decimal comma. `workoutMinutes` keys are the workout types listed in `workoutNames` in `src/sections.mjs`; anything else should be sent as `other`.

| Field | Unit | Shown on the site |
| --- | --- | --- |
| `steps` | count | daily average |
| `distanceMeters` | m, walking + running | 7-day total in km |
| `activeEnergy` | kcal | daily average |
| `exerciseMinutes` | min (Apple exercise ring) | fallback when there are no workouts |
| `workouts`, `workoutMinutes` | count, min per type | 7-day count, top three types, daily workout minutes as bars |
| `sleepMinutes` | min asleep, 18:00–12:00 | nightly average |
| `restingHeartRate` | bpm | daily average |
| `hrv` | ms, SDNN | daily average |
| `vo2Max` | ml/kg/min | latest value in the last 30 days |

### 1. Create a token

On GitHub: Settings → Developer settings → Fine-grained tokens → Generate new token.

- Repository access: only `leanderme/leanderso`
- Permissions: Contents, read and write (GitHub requires this for repository dispatch events)
- Expiration: up to one year; set a reminder to renew it

This token can push to the website repository, so it lives only on the phone: in the Health Push app's Keychain, or inside the Shortcut. If the phone is lost, revoke the token on GitHub.

### 2. Install Health Push

Follow `ios/README.md`: open `ios/HealthPush.xcodeproj`, run it on the iPhone, allow Health access, paste the token and send once to check. Then set up the daily Shortcuts automation described there, so the send happens at a fixed time every morning. That's all; the steps below are only needed without the app.

### Alternative: build a Shortcut

In the Shortcuts app, create a shortcut named "Send health summary". Health actions and their options differ a little between iOS versions, so treat these steps as the recipe and check the numbers before automating it:

1. **Date** set to Current Date, then **Adjust Date → Get Start of Day**. Name the result `Today`.
2. **Adjust Date**: subtract 1 day from `Today`. Name it `Yesterday`.
3. **Format Date** `Yesterday` with custom format `yyyy-MM-dd`. Name it `Day`.
4. **Find Health Samples** where Type is Steps and Start Date is between `Yesterday` and `Today`, grouped by Day. Then **Calculate Statistics → Sum** and name it `Steps`.
5. **Find Health Samples** where Type is Resting Heart Rate, same dates. **Calculate Statistics → Average** → `RestingHR`.
6. **Find Health Samples** where Type is Exercise Minutes, same dates, grouped by Day. **Calculate Statistics → Sum** → `ExerciseMinutes`.
7. **Find Health Samples** where Type is Workouts, same dates. **Count** → `Workouts`. If your iOS version doesn't offer workouts here, leave `workouts` out of the payload; the site then shows active minutes instead.
8. Sleep, for the night that ended this morning: **Adjust Date** to make `Yesterday` at 18:00 and `Today` at 12:00. **Find Health Samples** where Type is Sleep Analysis, Value is not In Bed and not Awake, and Start Date is between those two times. **Repeat with Each**: **Get Details of Health Sample → Duration**. After the loop, **Calculate Statistics → Sum** on the repeat results, convert to minutes → `SleepMinutes`. Durations may come back in seconds, so check this one against the Health app.
9. **Get Contents of URL** `https://api.github.com/repos/leanderme/leanderso/dispatches`
   - Method: POST
   - Headers: `Authorization` = `Bearer <token>`, `Accept` = `application/vnd.github+json`
   - Request Body: JSON with `event_type` = `health` and a Dictionary `client_payload` holding `date` = `Day`, `steps` = `Steps`, `sleepMinutes` = `SleepMinutes`, `restingHeartRate` = `RestingHR`, `exerciseMinutes` = `ExerciseMinutes`, `workouts` = `Workouts`

Before automating it, run the Shortcut once. Compare each number with yesterday's figures in the Health app; if steps come out about twice as high, iPhone and Watch samples were added together, so keep "group by Day" on. Then check the Actions tab for a successful Health run and a new commit to `data/health.json`.

#### Automate the Shortcut

Shortcuts → Automation → New → **Alarm: Is Stopped** (your wake-up alarm), set to Run Immediately, running "Send health summary". iOS protects Health data while the phone is locked, so a fixed time-of-day trigger at night often reads nothing. Stopping the alarm usually happens with the phone in hand.

Sending the same day twice simply replaces that day's figures.

### Test without the phone

The app can be tested in the Simulator against a local server; see `ios/README.md`. To exercise the real workflow:

```sh
gh api repos/leanderme/leanderso/dispatches -f event_type=health -f 'client_payload[date]=2026-11-05' -F 'client_payload[steps]=8432' -F 'client_payload[sleepMinutes]=431'
```

This commits real data to `main` and deploys it. Send a correct day afterwards to replace test figures.

## Prepared but disabled

- **Now in…** (`site.now` in `src/site.mjs`): add photos to `public/now/` (the configured paths are `1.jpg`–`3.jpg`, portrait 4:5 works best), write alt text for each, set `since` and `note` if wanted, and set `enabled: true`. The build stops if a photo or its alt text is missing. Only publish photos you hold the rights to, and get consent from anyone recognisable in them.
- **Newsletter** (`site.newsletter`): fill in `name`, `url` and an optional one-line `description`, then set `enabled: true`. It is a plain link to the newsletter's own page, so this site collects no email addresses and the privacy assessment stays unchanged; the privacy page then lists the newsletter among the external links automatically. An embedded sign-up form would need a new privacy assessment and a CSP change.
