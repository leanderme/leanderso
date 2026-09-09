# Legal review for leander.so

Reviewed 9 September 2026 against the sources below. This records the implementation assessment and remaining qualifications; it is not an individualized legal opinion or a guarantee of legal compliance.

## Scope

Personal static homepage of Leander Melms, labelled Privatperson, with name, Hamburg location, neutral links to Theodor.ai and Tonihealth.de, and Instagram, X and Threads. Separate German imprint and privacy pages, accessible from every page. No medical services, advice, editorial articles, checkout, advertising integrations, contact form, analytics, cookies, embeds, external fonts, server functions, or personal visitor log collection by the website operator.

The name and postal address were supplied for publication. The user confirmed `leander.melms@gmx.de` for the contact email. Social profiles were verified through the user's X page and Threads profile, which explicitly links Instagram.

## Imprint and unresolved contact issue

[Section 5 DDG](https://www.gesetze-im-internet.de/ddg/__5.html) requires identifying and contact details for businesslike digital services normally offered for remuneration. Direct payment on the website is not the only relevant factor. A personal homepage linking its operator's companies may also serve business purposes. Calling the operator a Privatperson does not conclusively establish an exemption.

[Section 18(1) MStV](https://www.die-medienanstalten.de/fileadmin/user_upload/Rechtsgrundlagen/Gesetze_Staatsvertraege/Medienstaatsvertrag_MStV.pdf) requires name and address for offerings beyond exclusively personal or family purposes. See also the [LFK regulator's imprint guidance](https://www.lfk.de/service/dokumente-rechtsgrundlagen/leitfaden-zur-impressumspflicht-im-internet).

Implemented: full name, serviceable street address, Germany, email, readily accessible Impressum link. No invented registration, VAT or medical professional details. The page offers no medical practice services, so professional particulars are not added merely because its owner is a physician. There is no journalism or editorial content requiring a separate §18(2) responsible editor under the assessed scope.

**Remaining qualification:** no phone or second rapid direct contact route has been provided. The [CJEU judgment C-298/07](https://eur-lex.europa.eu/legal-content/DE/ALL/?uri=CELEX%3A62007CJ0298) states that a telephone number is not invariably mandatory, but additional information enabling rapid, direct and effective communication alongside email is required where the commercial information duty applies. An effectively operated contact form can qualify; ordinary social profile links are not assumed to satisfy this. The user asked whether a phone was necessary and was told about this distinction. The site is being published with email only; full §5 contact compliance is not claimed. If the businesslike classification is confirmed, add a working second contact route. Do not publish a private number obtained from unrelated account settings.

## Privacy

The privacy page covers operator identity/contact, hosting data, purposes, legitimate interests and legal basis, recipients, possible international transfers, retention criteria, direct contact, rights and the right to complain. [GDPR Articles 6, 13, 15–21 and 77](https://eur-lex.europa.eu/eli/reg/2016/679/oj). The responsible local regulator is the [Hamburg Commissioner for Data Protection and Freedom of Information](https://datenschutz-hamburg.de/service-information/beschwerde-oder-hinweis-einreichen).

The deployment is static HTML/CSS with no app-side cookies, device storage, analytics or external embedded resources. Under [§25 TDDDG](https://www.gesetze-im-internet.de/ttdsg/TDDDG.pdf), a consent banner is not indicated by this implementation. External social/company connections occur only when a visitor opens the corresponding link. Links use `noreferrer`, and the response referrer policy is `no-referrer`.

### Vercel hosting

The existing team is on Hobby. The [current Vercel DPA](https://vercel.com/legal/dpa) distinguishes Pro/Enterprise processor activity from independently controlled system-generated data. The website does **not** claim that a Hobby AVV exists or that processing stays exclusively in the EU.

The [BayLDA's static hosting guidance](https://www.lda.bayern.de/media/veroeffentlichungen/FAQ_Hosting_keine_Auftragsverarbeitung.pdf) explains that pure static self-presentation hosting can fall outside commissioned processing when there is no tracking and no personal pageview data supplied to the site operator. Vercel's own controller description is consistent with that interpretation for this limited deployment. Actual processing matters more than contractual labels: [EDPB Guidelines 07/2020](https://www.edpb.europa.eu/documents/guideline/guidelines-072020-on-the-concepts-of-controller-and-processor-in-the-gdpr_en).

No analytics, Speed Insights, log drains, middleware or runtime functions are configured. Do not collect identifiable visitor logs or add processing features under this assessment. Vercel's infrastructure may process connection/security data for its own purposes. Its [privacy notice](https://vercel.com/legal/privacy-notice) supplies details on recipients, transfers and purpose-dependent retention. No arbitrary seven-day or one-hour universal deletion promise is made.

**Plan qualification:** Vercel [Hobby fair-use terms](https://vercel.com/docs/limits/fair-use-guidelines) restrict commercial use and include advertising product/service sales as an example. This site uses neutral biographical company links with no sales copy or purchase flow; classification of this exact case is not settled by the cited documentation. A promotional/commercial expansion should use an eligible plan and trigger a renewed privacy assessment. No paid upgrade was purchased.

## Requirements not triggered by this scope

- No outdated EU online dispute resolution link: the relevant platform legislation was repealed from 20 July 2025 by [Regulation (EU) 2024/3228](https://eur-lex.europa.eu/eli/reg/2024/3228/oj).
- No consumer-contract process, so generic [§36 VSBG](https://www.gesetze-im-internet.de/vsbg/__36.html) dispute-resolution boilerplate is not added.
- No electronic commerce service concluding consumer contracts in the assessed scope: [BFSG §1](https://www.gesetze-im-internet.de/bfsg/__1.html), [§2(26)](https://www.gesetze-im-internet.de/bfsg/__2.html). Semantic HTML, responsive layout, focus outlines, readable text and reduced-motion support are nevertheless implemented.

Reassess when adding editorial content, commercial offers, medical practice services, forms, analytics, tracking, embedded media, or new data-processing services.
