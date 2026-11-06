// Validates one day of Apple Health figures from the iOS Shortcut and stores it in data/health.json.
// Run by .github/workflows/health.yml with the repository_dispatch payload in HEALTH_PAYLOAD.
import { readFile, writeFile } from 'node:fs/promises';

const file = new URL('../data/health.json', import.meta.url);
const keep = 120;
const fields = {
  steps: [0, 100000],
  sleepMinutes: [0, 1440],
  restingHeartRate: [25, 150],
  exerciseMinutes: [0, 1440],
  workouts: [0, 20],
};

const payload = JSON.parse(process.env.HEALTH_PAYLOAD ?? '{}');
const date = String(payload.date ?? '');
const age = (Date.now() - Date.parse(`${date}T12:00:00Z`)) / 864e5;
if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !(age > -2 && age < 14)) throw new Error(`Expected a recent date as YYYY-MM-DD, got "${date}".`);

const day = { date };
for (const [key, [min, max]] of Object.entries(fields)) {
  const raw = payload[key];
  if (raw === undefined || raw === null || raw === '') continue;
  // Shortcuts may send numbers as strings, sometimes with a decimal comma.
  const value = Number(String(raw).replace(',', '.'));
  if (!Number.isFinite(value) || value < min || value > max) throw new Error(`${key} must be between ${min} and ${max}, got "${raw}".`);
  day[key] = Math.round(value);
}
if (Object.keys(day).length === 1) throw new Error('The payload contained no health figures.');

const stored = JSON.parse(await readFile(file, 'utf8').catch(() => '{"days":[]}'));
const days = [...stored.days.filter(entry => entry.date !== date), day].sort((a, b) => a.date.localeCompare(b.date)).slice(-keep);
await writeFile(file, `{"days":[\n${days.map(entry => JSON.stringify(entry)).join(',\n')}\n]}\n`);
console.log(`Recorded ${JSON.stringify(day)}.`);
