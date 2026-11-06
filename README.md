# leander.so

Leander Melms's personal website. A small, responsive static site with company and social links, an imprint, and privacy information.

## Development

Requires Node.js 22+ and Python 3 for the local preview. No application dependencies are needed.

```sh
npm run dev
```

Open http://127.0.0.1:4173. Run `npm run build` after an edit to refresh the static output.

## Editing

- `src/site.mjs`: name, address, contact information, company and social links, and the prepared Now and newsletter sections.
- `src/build.mjs`: shared HTML layout, page copy, metadata, and static build.
- `src/sections.mjs`: homepage sections built from data (GitHub activity, health) and the optional Now and newsletter sections.
- `ios/`: Health Push, the iPhone app that sends the daily Apple Health summary. See `ios/README.md`.
- `data/`: GitHub and Apple Health figures, committed by GitHub Actions. See `docs/live-data.md` for how they update and how to enable the prepared sections.
- `public/style.css`: responsive layout, typography, colors, focus and hover states.
- `public/fonts/`: self-hosted Newsreader font and its SIL Open Font License.
- `public/icons/`: supplied company brand marks and original social favicons, served locally beside their links.
- `docs/legal-review.md`: legal sources, reasoning, and remaining limitations.

## Deployment

Vercel builds `main` from `leanderme/leanderso` with `npm run build` and serves `dist`. The framework preset is Other. `vercel.json` defines this configuration, canonical trailing slashes, and security headers.

GitHub activity is refreshed daily and Apple Health figures arrive from an iOS Shortcut; both are committed to `data/` by GitHub Actions, which triggers a normal Vercel deployment.

The website contains no client-side JavaScript, cookies, tracking, embedded social content, fonts loaded from third parties, API endpoints, or server functions. Newsreader is served from the same origin under the SIL Open Font License; its Latin font file comes from the Google Fonts distribution. Do not add analytics, forms, or visitor logging without updating the privacy assessment and privacy page.

The production domain is https://leander.so. Domain records remain managed in Namecheap.
