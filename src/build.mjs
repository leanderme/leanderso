import { cp, mkdir, rm, writeFile } from 'node:fs/promises';
import { site } from './site.mjs';

const escape = (value) => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
const external = ({ name, url }) => `<a class="index-link" href="${escape(url)}" rel="noreferrer">${escape(name)}<span class="arrow" aria-hidden="true">↗</span></a>`;
const list = (links) => `<ul class="link-list">${links.map(link => `<li>${external(link)}</li>`).join('')}</ul>`;
const address = `<address>${escape(site.name)}<br>${site.address.map(escape).join('<br>')}</address>`;
const contact = `${site.email ? `<p>E-Mail: <a href="mailto:${escape(site.email)}">${escape(site.email)}</a></p>` : '<p>E-Mail: vor Veröffentlichung zu ergänzen.</p>'}${site.phone ? `<p>Telefon: <a href="tel:${escape(site.phone)}">${escape(site.phone)}</a></p>` : ''}`;
const footer = `<footer class="footer"><span>© ${new Date().getUTCFullYear()} ${escape(site.name)}</span><nav aria-label="Rechtliches" lang="de"><a href="/impressum/">Impressum</a><a href="/datenschutz/">Datenschutz</a></nav></footer>`;
const masthead = (home) => `<header class="masthead"><a class="wordmark" href="/" aria-label="Leander Melms — Home"><span class="mark" aria-hidden="true"></span>leander.so</a>${home ? `<span class="location">${escape(site.city)}</span>` : '<a class="back" href="/">← Startseite</a>'}</header>`;

function document({ title, description, path, body, lang = 'de', home = false }) {
  return `<!doctype html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escape(title)}</title>
  <meta name="description" content="${escape(description)}">
  <meta name="theme-color" content="#fafafa">
  <meta name="referrer" content="no-referrer">
  <link rel="canonical" href="${escape(site.url + path)}">
  <meta property="og:type" content="website">
  <meta property="og:title" content="${escape(title)}">
  <meta property="og:description" content="${escape(description)}">
  <meta property="og:url" content="${escape(site.url + path)}">
  <meta name="twitter:card" content="summary">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/style.css">
</head>
<body>
  <a class="skip" href="#main">${home ? 'Skip to content' : 'Zum Inhalt'}</a>
  <div class="page ${home ? 'home' : 'legal'}">
    ${masthead(home)}
    <main id="main">${body}</main>
    ${footer}
  </div>
</body>
</html>`;
}

const pages = [
  {
    file: 'index.html', path: '/', lang: 'en', home: true,
    title: 'Leander Melms',
    description: 'Leander Melms. Hamburg, Germany. Theodor.ai, Tonihealth.de, and elsewhere on the internet.',
    body: `<div class="intro"><h1>Leander Melms<span aria-hidden="true">.</span></h1></div>
      <section class="index-section" aria-labelledby="companies"><h2 class="section-label" id="companies">Companies</h2>${list(site.companies)}</section>
      <section class="index-section socials" aria-labelledby="elsewhere"><h2 class="section-label" id="elsewhere">Elsewhere</h2>${list(site.socials)}</section>`,
  },
  {
    file: 'impressum/index.html', path: '/impressum/',
    title: 'Impressum — Leander Melms',
    description: 'Anbieterkennzeichnung und Kontakt für die persönliche Website von Leander Melms.',
    body: `<h1>Impressum</h1><div class="prose">
      <h2>Anbieterkennzeichnung</h2>
      ${address}<p>Privatperson</p>
      <h2>Kontakt</h2>${contact}
      <h2>Über diese Website</h2><p>Dies ist die persönliche Website von Leander Melms. Die verlinkten Unternehmen und Plattformen sind eigenständige Angebote. Die jeweilige Anbieterkennzeichnung ist auf deren Websites abrufbar.</p>
    </div>`,
  },
  {
    file: 'datenschutz/index.html', path: '/datenschutz/',
    title: 'Datenschutz — Leander Melms',
    description: 'Informationen zum Datenschutz beim Besuch von leander.so und bei der Kontaktaufnahme.',
    body: `<h1>Datenschutz</h1><div class="prose">
      <p>Diese Hinweise informieren über die Verarbeitung personenbezogener Daten beim Besuch von leander.so und bei der Kontaktaufnahme.</p>
      <h2>Verantwortlicher</h2>${address}${contact}
      <h2>Bereitstellung der Website</h2>
      <p>Diese Website besteht aus statischen Seiten. Sie wird über Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, USA, bereitgestellt. Beim Abruf erhält Vercel technisch notwendige Verbindungsdaten, insbesondere die IP-Adresse, Datum und Uhrzeit, die angeforderte Adresse sowie Browser- und Geräteinformationen. Diese Daten dienen der Auslieferung, Stabilität und Sicherheit der Website.</p>
      <p>Die Bereitstellung erfolgt auf Grundlage von Art. 6 Abs. 1 lit. f DSGVO. Das berechtigte Interesse liegt in einer sicheren und zuverlässigen Darstellung dieser persönlichen Website. Ohne die technisch notwendigen Verbindungsdaten kann die Website nicht ausgeliefert werden.</p>
      <p>Vercel verarbeitet systemgenerierte Daten nach seinen Datenschutzbedingungen in eigener Verantwortlichkeit. Die Verarbeitung kann in den USA und weiteren Ländern erfolgen. Angaben zu Empfängern, Speicherdauer und Garantien für internationale Übermittlungen finden sich in der <a href="https://vercel.com/legal/privacy-notice" rel="noreferrer">Datenschutzerklärung von Vercel</a>. Für Übermittlungen in Drittländer nennt Vercel insbesondere das EU-US Data Privacy Framework bei anwendbarer Zertifizierung sowie Standardvertragsklauseln. Eine ausschließlich europäische Verarbeitung wird nicht zugesichert.</p>
      <p>Ich betreibe auf dieser Website keine eigene Besucherauswertung und führe keine eigenen personenbezogenen Zugriffsprotokolle. Vercel bewahrt diese Daten nach eigenen Angaben so lange auf, wie sie für die jeweiligen Zwecke oder rechtliche Verpflichtungen erforderlich sind, und löscht oder anonymisiert sie anschließend.</p>
      <h2>Cookies und externe Inhalte</h2>
      <p>Diese Website setzt selbst keine Cookies und nutzt weder Webanalyse noch Werbetracking. Es gibt keine Social-Media-Einbettungen, extern geladenen Schriftarten oder Kontaktformulare. Die Seiten funktionieren ohne JavaScript. Eine Einwilligung für optionale Speicher- oder Zugriffsvorgänge nach § 25 TDDDG ist für diese Gestaltung nicht erforderlich.</p>
      <h2>Links zu anderen Websites</h2>
      <p>Die Verweise auf Unternehmen, Instagram, X und Threads sind einfache Links. Erst wenn Sie einen Link aufrufen, wird eine Verbindung zum jeweiligen Angebot hergestellt. Für die dortige Datenverarbeitung gelten die Datenschutzhinweise des jeweiligen Anbieters.</p>
      <h2>Kontaktaufnahme</h2>
      <p>Wenn Sie mich kontaktieren, verarbeite ich Ihre Kontaktdaten und die von Ihnen übermittelten Inhalte zur Bearbeitung Ihrer Anfrage. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO; das berechtigte Interesse ist die Beantwortung von Anfragen. Soweit die Verarbeitung zur Erfüllung eines Vertrags mit Ihnen oder zur Durchführung vorvertraglicher Maßnahmen auf Ihre Anfrage erforderlich ist, erfolgt sie auf Grundlage von Art. 6 Abs. 1 lit. b DSGVO. Die Angaben sind freiwillig; ohne eine erreichbare Kontaktadresse kann ich gegebenenfalls nicht antworten.</p>
      <p>Für Empfang, Speicherung und Versand von E-Mails nutze ich GMX, einen Dienst der 1&amp;1 Mail &amp; Media GmbH, Brauerstraße 48, 76135 Karlsruhe, Deutschland. Dabei verarbeitet der Anbieter die zur E-Mail-Kommunikation erforderlichen Adress-, Inhalts- und Verbindungsdaten. Weitere Informationen enthalten die <a href="https://agb-server.gmx.net/datenschutz" rel="noreferrer">Datenschutzhinweise von GMX</a>.</p>
      <p>Nach Abschluss der Anfrage werden die Daten gelöscht, sobald sie für die Bearbeitung nicht mehr erforderlich sind, keine gesetzlichen Aufbewahrungspflichten bestehen und die weitere Speicherung nicht zur Geltendmachung, Ausübung oder Verteidigung von Rechtsansprüchen erforderlich ist.</p>
      <h2>Ihre Rechte</h2>
      <p>Unter den gesetzlichen Voraussetzungen haben Sie das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung und Datenübertragbarkeit nach Art. 15 bis 20 DSGVO.</p>
      <p><strong>Bei einer Verarbeitung auf Grundlage von Art. 6 Abs. 1 lit. f DSGVO können Sie aus Gründen, die sich aus Ihrer besonderen Situation ergeben, nach Art. 21 DSGVO widersprechen.</strong> Wenden Sie sich hierfür an die oben genannte Kontaktadresse.</p>
      <p>Sie können sich nach Art. 77 DSGVO bei einer Datenschutzaufsichtsbehörde beschweren, insbesondere an Ihrem gewöhnlichen Aufenthaltsort, Ihrem Arbeitsplatz oder am Ort des vermuteten Verstoßes. Für Hamburg ist dies <a href="https://datenschutz-hamburg.de/" rel="noreferrer">Der Hamburgische Beauftragte für Datenschutz und Informationsfreiheit</a>.</p>
      <p>Es findet keine automatisierte Entscheidungsfindung oder Profilbildung durch mich statt.</p>
      <p>Stand: 9. September 2026</p>
    </div>`,
  },
  {
    file: '404.html', path: '/404.html', lang: 'en',
    title: 'Page not found — Leander Melms',
    description: 'This page could not be found.',
    body: '<h1>A wrong turn.</h1><div class="prose"><p>This page could not be found.</p><p><a href="/">Back to leander.so →</a></p></div>',
  },
];

if (process.env.VERCEL && !site.email) throw new Error('Add the confirmed public contact email in src/site.mjs before deployment.');
await rm('dist', { recursive: true, force: true });
await mkdir('dist', { recursive: true });
await cp('public', 'dist', { recursive: true });
for (const page of pages) {
  const target = new URL(`../dist/${page.file}`, import.meta.url);
  await mkdir(new URL('.', target), { recursive: true });
  await writeFile(target, document(page));
}
await writeFile('dist/robots.txt', `User-agent: *\nAllow: /\nSitemap: ${site.url}/sitemap.xml\n`);
await writeFile('dist/sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${pages.filter(page => page.file !== '404.html').map(page => `<url><loc>${escape(site.url + page.path)}</loc></url>`).join('')}</urlset>`);
console.log(`Built ${pages.length} static pages. No client-side JavaScript or third-party assets.`);
