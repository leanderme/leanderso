export const site = {
  name: 'Leander Melms',
  url: 'https://leander.so',
  city: 'Hamburg, Germany',
  introduction: 'Building for a healthier future.',
  email: 'leander.melms@gmx.de',
  phone: '',
  address: ['Felix-Dahn-Straße 4', '20357 Hamburg', 'Deutschland'],
  companies: [
    { name: 'Theodor.ai', url: 'https://theodor.ai/', icon: '/icons/theodor-heart.png' },
    { name: 'Tonihealth.de', url: 'https://tonihealth.de/', icon: '/icons/tonihealth-heart.png' },
  ],
  socials: [
    { name: 'Instagram', url: 'https://www.instagram.com/leanderbuilds/', icon: '/icons/instagram.webp' },
    { name: 'X', url: 'https://x.com/leanderbuilds', icon: '/icons/x.png' },
    { name: 'Threads', url: 'https://www.threads.com/@leander.builds', icon: '/icons/threads.webp' },
  ],
  // Contributions are refreshed daily by .github/workflows/github-activity.yml into data/github.json.
  github: { login: 'leanderme', url: 'https://github.com/leanderme' },
  // Apple Health summaries arrive through .github/workflows/health.yml into data/health.json.
  // The section hides itself when the newest day is older than this.
  health: { staleAfterDays: 10 },
  // Prepared, not yet shown. Add photos to public/now/ with alt text, then set enabled: true.
  now: {
    enabled: false,
    place: 'Cyprus',
    since: '',
    note: '',
    images: [
      { src: '/now/1.jpg', alt: '', width: 1200, height: 1500 },
      { src: '/now/2.jpg', alt: '', width: 1200, height: 1500 },
      { src: '/now/3.jpg', alt: '', width: 1200, height: 1500 },
    ],
  },
  // Prepared, not yet shown. A plain link to the newsletter's own page, so this site collects no addresses.
  newsletter: { enabled: false, name: '', url: '', description: '' },
};
