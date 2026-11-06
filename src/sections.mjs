// Homepage sections built from data/*.json and the optional parts of site.mjs. Everything renders to static HTML and inline SVG.
import { existsSync, readFileSync } from 'node:fs';
import { site } from './site.mjs';

export const escape = (value) => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
const readData = (name) => { const file = new URL(`../data/${name}.json`, import.meta.url); return existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : null; };
const day = 864e5;
const addDays = (date, days) => new Date(Date.parse(`${date}T00:00:00Z`) + days * day).toISOString().slice(0, 10);
const formatDate = (date, options) => new Date(`${date}T00:00:00Z`).toLocaleDateString('en-GB', { timeZone: 'UTC', ...options });
const number = (value) => Math.round(value).toLocaleString('en-US');
const section = (id, label, content) => `<section class="index-section ${id}" aria-labelledby="${id}"><h2 class="section-label" id="${id}">${label}</h2><div>${content}</div></section>`;
const arrow = '<span class="link-arrow" aria-hidden="true">↗</span>';

export function code() {
  const github = readData('github');
  if (!github) return '';
  const offset = new Date(`${github.start}T00:00:00Z`).getUTCDay();
  const columns = Math.ceil((offset + github.counts.length) / 7);
  const active = github.counts.filter(Boolean).sort((a, b) => a - b);
  const thresholds = [.25, .5, .75].map(q => active[Math.floor(q * (active.length - 1))] ?? 0);
  const level = (count) => count === 0 ? 0 : 1 + thresholds.filter(t => count > t).length;
  const dots = github.counts.map((count, i) => {
    const position = offset + i;
    const date = formatDate(addDays(github.start, i), { day: 'numeric', month: 'short', year: 'numeric' });
    return `<circle class="l${level(count)}" cx="${Math.floor(position / 7) * 10 + 5}" cy="${(position % 7) * 10 + 5}" r="3.5"><title>${count} contribution${count === 1 ? '' : 's'} on ${date}</title></circle>`;
  }).join('');
  const end = addDays(github.start, github.counts.length - 1);
  const monthYear = (date) => formatDate(date, { month: 'short', year: 'numeric' });
  return section('code', 'Code', `<a class="index-link" href="${escape(site.github.url)}" rel="noreferrer"><span class="link-name">${number(github.total)} contributions on GitHub</span>${arrow}</a>
    <svg class="calendar" viewBox="0 0 ${columns * 10} 70" role="img" aria-label="${number(github.total)} GitHub contributions per day from ${monthYear(github.start)} to ${monthYear(end)}">${dots}</svg>
    <p class="axis"><span>${monthYear(github.start)}</span><span>${monthYear(end)}</span></p>`);
}

const spark = (values, { floor = 0 } = {}) => {
  const present = values.filter(value => value != null);
  if (present.length < 2) return '';
  const max = Math.max(...present);
  const min = floor === 'auto' ? Math.min(...present) - (max - Math.min(...present) || 1) : floor;
  const bars = values.map((value, i) => value == null ? '' : `<rect x="${i * 4}" y="${24 - Math.max(1, (value - min) / (max - min || 1) * 24)}" width="2.5" height="${Math.max(1, (value - min) / (max - min || 1) * 24)}"/>`).join('');
  return `<svg class="spark" viewBox="0 0 ${values.length * 4 - 1.5} 24" preserveAspectRatio="none" aria-hidden="true">${bars}</svg>`;
};

export function health(today = new Date().toISOString().slice(0, 10)) {
  const days = readData('health')?.days ?? [];
  const latest = days.at(-1)?.date;
  if (!latest || (Date.parse(today) - Date.parse(latest)) / day > site.health.staleAfterDays) return '';
  const byDate = new Map(days.map(entry => [entry.date, entry]));
  const series = (key, length) => Array.from({ length }, (_, i) => byDate.get(addDays(latest, i - length + 1))?.[key] ?? null);
  const week = (key) => series(key, 7).filter(value => value != null);
  const average = (key) => { const values = week(key); return values.length ? values.reduce((a, b) => a + b, 0) / values.length : null; };
  const sum = (key) => { const values = week(key); return values.length ? values.reduce((a, b) => a + b, 0) : null; };
  const sleep = average('sleepMinutes');
  const figures = [
    { value: average('steps'), text: number, label: 'steps a day', bars: spark(series('steps', 30)) },
    { value: sleep, text: () => `${Math.floor(Math.round(sleep) / 60)}:${String(Math.round(sleep) % 60).padStart(2, '0')}`, label: 'hours of sleep a night', bars: spark(series('sleepMinutes', 30)) },
    { value: average('restingHeartRate'), text: number, label: 'bpm resting heart rate', bars: spark(series('restingHeartRate', 30), { floor: 'auto' }) },
    sum('workouts') != null
      ? { value: sum('workouts'), text: number, label: `workout${sum('workouts') === 1 ? '' : 's'} this week${sum('exerciseMinutes') ? `, ${number(sum('exerciseMinutes'))} active minutes` : ''}`, bars: spark(series('exerciseMinutes', 30)) }
      : { value: sum('exerciseMinutes'), text: number, label: 'active minutes this week', bars: spark(series('exerciseMinutes', 30)) },
  ].filter(figure => figure.value != null);
  if (!figures.length) return '';
  const items = figures.map(figure => `<div class="figure"><p class="figure-value">${figure.text(figure.value)}</p><p class="figure-label">${figure.label}</p>${figure.bars}</div>`).join('');
  return section('health', 'Health', `<div class="figures">${items}</div><p class="note">Seven-day averages from Apple Health, through ${formatDate(latest, { day: 'numeric', month: 'long' })}. Bars show the last 30 days.</p>`);
}

export function newsletter() {
  const { enabled, name, url, description } = site.newsletter;
  if (!enabled) return '';
  if (!name || !url) throw new Error('Set newsletter.name and newsletter.url in src/site.mjs before enabling it.');
  return section('newsletter', 'Newsletter', `<a class="index-link" href="${escape(url)}" rel="noreferrer"><span class="link-name">${escape(name)}</span>${arrow}</a>${description ? `<p class="note">${escape(description)}</p>` : ''}`);
}

export function now() {
  const { enabled, place, since, note, images } = site.now;
  if (!enabled) return '';
  for (const image of images) {
    if (!existsSync(new URL(`../public${image.src}`, import.meta.url))) throw new Error(`Add ${image.src} to public/ before enabling the Now section.`);
    if (!image.alt) throw new Error(`Describe ${image.src} in its alt text before enabling the Now section.`);
  }
  const photos = images.map(image => `<img src="${escape(image.src)}" alt="${escape(image.alt)}" width="${image.width}" height="${image.height}" loading="lazy" decoding="async">`).join('');
  return `<section class="now" aria-labelledby="now"><h2 id="now">Now in ${escape(place)}</h2>${since ? `<p class="now-since">Since ${escape(since)}</p>` : ''}${note ? `<p class="now-note">${escape(note)}</p>` : ''}${photos ? `<div class="now-photos">${photos}</div>` : ''}</section>`;
}
