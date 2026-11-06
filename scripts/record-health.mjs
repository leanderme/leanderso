// Validates Apple Health figures from Health Push (or the iOS Shortcut) and stores them in data/health.json.
// Run by .github/workflows/health.yml with the repository_dispatch payload in HEALTH_PAYLOAD:
// either { days: [day, …] } or a single day. Each day sent replaces the stored day with the same date.
import { readFile, writeFile } from 'node:fs/promises';

const file = new URL('../data/health.json', import.meta.url);
const keep = 120;
const maxAgeDays = 40;
// [min, max, decimals]
const fields = {
  steps: [0, 100000, 0],
  distanceMeters: [0, 200000, 0],
  activeEnergy: [0, 10000, 0],
  exerciseMinutes: [0, 1440, 0],
  workouts: [0, 20, 0],
  sleepMinutes: [0, 1440, 0],
  restingHeartRate: [25, 150, 0],
  hrv: [1, 300, 0],
  vo2Max: [10, 90, 1],
};
const workoutTypes = /^[a-z][a-z]{1,15}$/;

// Shortcuts may send numbers as strings, sometimes with a decimal comma.
const parse = (key, raw, [min, max, decimals]) => {
  const value = Number(String(raw).replace(',', '.'));
  if (!Number.isFinite(value) || value < min || value > max) throw new Error(`${key} must be between ${min} and ${max}, got "${raw}".`);
  return Math.round(value * 10 ** decimals) / 10 ** decimals;
};

function validate(payload) {
  const date = String(payload.date ?? '');
  const age = (Date.now() - Date.parse(`${date}T12:00:00Z`)) / 864e5;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !(age > -2 && age < maxAgeDays)) throw new Error(`Expected a date within the last ${maxAgeDays} days as YYYY-MM-DD, got "${date}".`);

  const day = { date };
  for (const [key, range] of Object.entries(fields)) {
    const raw = payload[key];
    if (raw !== undefined && raw !== null && raw !== '') day[key] = parse(key, raw, range);
  }
  if (payload.workoutMinutes != null) {
    const entries = Object.entries(payload.workoutMinutes);
    if (typeof payload.workoutMinutes !== 'object' || entries.length > 12) throw new Error('workoutMinutes must map up to 12 workout types to minutes.');
    for (const [type, minutes] of entries) {
      if (!workoutTypes.test(type)) throw new Error(`Unknown workout type "${type}".`);
      (day.workoutMinutes ??= {})[type] = parse(`workoutMinutes.${type}`, minutes, [0, 1440, 0]);
    }
  }
  return Object.keys(day).length > 1 ? day : null;
}

const payload = JSON.parse(process.env.HEALTH_PAYLOAD ?? '{}');
const incoming = (Array.isArray(payload.days) ? payload.days : [payload]).map(validate).filter(Boolean);
if (!incoming.length) throw new Error('The payload contained no health figures.');
if (new Set(incoming.map(day => day.date)).size !== incoming.length) throw new Error('The payload contains the same date twice.');

const stored = JSON.parse(await readFile(file, 'utf8').catch(() => '{"days":[]}'));
const sent = new Set(incoming.map(day => day.date));
const days = [...stored.days.filter(entry => !sent.has(entry.date)), ...incoming].sort((a, b) => a.date.localeCompare(b.date)).slice(-keep);
await writeFile(file, `{"days":[\n${days.map(entry => JSON.stringify(entry)).join(',\n')}\n]}\n`);
console.log(`Recorded ${incoming.length} day${incoming.length === 1 ? '' : 's'}, ${incoming[0].date} to ${incoming.at(-1).date}.`);
