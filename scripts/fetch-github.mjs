// Fetches the public contribution calendar into data/github.json. Run daily by .github/workflows/github-activity.yml.
import { writeFile } from 'node:fs/promises';
import { site } from '../src/site.mjs';

const token = process.env.GITHUB_TOKEN;
if (!token) throw new Error('Set GITHUB_TOKEN to query the GitHub GraphQL API.');

const query = `query($login: String!) { user(login: $login) { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount } } } } } }`;
const response = await fetch('https://api.github.com/graphql', {
  method: 'POST',
  headers: { authorization: `bearer ${token}`, 'content-type': 'application/json', 'user-agent': 'leanderso-build' },
  body: JSON.stringify({ query, variables: { login: site.github.login } }),
});
const { data, errors } = await response.json();
if (!response.ok || errors) throw new Error(`GitHub API: ${response.status} ${JSON.stringify(errors ?? '')}`);

const calendar = data.user.contributionsCollection.contributionCalendar;
const days = calendar.weeks.flatMap(week => week.contributionDays);
const result = { login: site.github.login, total: calendar.totalContributions, start: days[0].date, counts: days.map(day => day.contributionCount) };
await writeFile(new URL('../data/github.json', import.meta.url), JSON.stringify(result) + '\n');
console.log(`${result.total} contributions from ${result.start}, ${days.length} days.`);
