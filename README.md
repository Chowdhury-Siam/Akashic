# Yutaka Website 1.3.0 — interactive demo + Cloudflare deployment

A responsive public website and app-style browser demo for Yutaka, based on the original Flutter 1.0.1193 design and artwork. The website is separate from the installed Yutaka app and its self-hosted sync Worker.

## Website features

- Interactive demo at `/demo/`: Home, Analysis, Loans, Transactions, Categories, accounts, budgets, plans, subscriptions, and notes. It starts with fictional records and stores any visitor edits only in that browser's `localStorage`.
- Responsive desktop/mobile layouts, dark styling, accessible controls, and a link to the Yutaka source repository.
- Social share previews for the homepage and interactive demo use the **same square launcher icon as the installed Yutaka app**. The Open Graph and Twitter preview assets have a versioned URL to avoid serving older cached image files.
- Google Play and Microsoft Store buttons, configured automatically **from GitHub Actions secrets**, with independent **Coming soon** placeholders until genuine listing links are supplied.
- Cloudflare Workers **Static Assets** hosting: **no website database, Turso integration, email collection, waitlist, rate-limit key, or separate API Worker**.

The Yutaka **installed app** can still optionally connect to its owner's separate Cloudflare sync Worker and private Turso database. The *public website* neither accesses nor needs that database. No live app accounts, cloud sync, backup, native notifications, native exports, or background services are included in the fictional browser demo.

## GitHub Actions deployment

This project must be at the **repository root** (including the hidden `.github` directory). The workflow is `.github/workflows/deploy-website.yml`. Pushes to `main` deploy the website when website files change. **Actions → Deploy Yutaka Website → Run workflow** also deploys it manually. Pull requests run tests and the bundle check only; forked repositories are not authorized to deploy through the bundled workflow.

In **GitHub repository → Settings → Secrets and variables → Actions**, configure:

| Type | Name | Required | Value |
| --- | --- | --- | --- |
| Secret | `CLOUDFLARE_WORKER_NAME` | Yes | Your Worker name, e.g. `siam-yutaka` (lowercase letters, digits and hyphens; maximum 63 characters) |
| Secret | `CLOUDFLARE_API_TOKEN` | Yes | A Cloudflare API token with Workers edit permission |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | Yes | Your Cloudflare account ID |
| Secret | `PLAY_STORE_URL` | No | Your published listing, e.g. `https://play.google.com/store/apps/details?id=YOUR.PACKAGE` |
| Secret | `MICROSOFT_STORE_URL` | No | Your published listing, e.g. `https://apps.microsoft.com/detail/YOUR-STORE-ID` |

`CLOUDFLARE_WORKER_NAME` is read **only from GitHub Actions secrets**. There is no manual Worker-name workflow input, repository-variable lookup, or fallback. Both push and manual deployments use the same saved secret; a missing or invalid Worker name fails early. Changing the secret deploys a different Worker and does not delete the old one.

The two store URLs are **only configured from GitHub Actions secrets**. The workflow validates the URLs and generates `public/assets/config.js` in its temporary checkout before deploying. **Do not edit or commit store URLs to `config.js`.** Each secret is optional; if one is missing, that store's button stays at “Coming soon” while the other can be enabled. To publish a changed URL, update the GitHub secret and **rerun the deployment workflow** (changing a secret does not automatically start a run). Listing URLs are public links once deployed even though the configuration uses GitHub's encrypted-secret interface: never store API tokens or other confidential data in these URL secrets.

If you use a GitHub `production` environment, configure access to the repository or environment secrets there as appropriate; the workflow's deploy job specifies `environment: production`. Its test job does not require deployment secrets. The deployment summary shows the selected Worker name and, when available, the public URL.

### Custom domain

In Cloudflare, open **Workers & Pages → your Worker → Settings → Domains & Routes** and attach your custom domain. Configure the domain's DNS/HTTPS in Cloudflare. Changing the Worker name may require reassigning the domain.

### Previously deployed website with Turso

This version removes the entire website-specific Turso and release-notification implementation, including its migration scripts and signup API. If you previously deployed the old website, delete the **old website Worker's** unused `TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN`, and `RATE_LIMIT_KEY` secrets in Cloudflare after updating. An old *website-only* Turso database can be retired after you export or dispose of any existing release-notification contacts according to your privacy commitments. **Do not delete the installed Yutaka app's private sync database or Worker credentials.**

## Local development

Node.js 22 is recommended (20 or later required):

```bash
npm ci
npm test
npm run check:bundle
npm run dev
```

Visit the local Workers URL printed by Wrangler (typically `http://localhost:8787`), then `/demo/`. Local previews intentionally display “Coming soon” for both stores. To test URL generation without committing them, supply `PLAY_STORE_URL` and `MICROSOFT_STORE_URL` to `npm run configure:stores` in a disposable checkout; it overwrites the local `config.js`. GitHub Actions generates that file automatically during real deployment. For an ordinary local deployment, `npm run deploy` uses `wrangler.jsonc` and your authenticated Cloudflare account; the GitHub Actions Worker-name secret is applied by the GitHub workflow, not by a local deploy.

## Social link previews

The homepage and `/demo/` advertise `/assets/yutaka-app-social-v1.3.0.png`, a copy of the app launcher icon. New shares on Telegram and other services should use the updated icon after the website is redeployed. Previously sent messages or cached URL previews may continue to show the older image until that platform refreshes its preview.

## Key routes

| URL | Purpose |
| --- | --- |
| `/` | Public landing page and store links |
| `/demo/` | Interactive fictional-data demo |
| `/privacy/` | Website privacy template; customize before public launch |

There is **no `/api/waitlist` or `/api/health` endpoint** and no website database. The demo is a source-guided HTML/CSS/JavaScript recreation, not a compiled Flutter Web build. Native background scheduling, media upload, cross-device sync, PDF/XLSX/TXT exports, and notifications remain available only where implemented in the installed Yutaka app, not in the website demo.

## Pre-publication naming check

Before publishing, verify trademark clearance, domain availability, and store-listing availability for the **Yutaka** name in the regions where you plan to distribute the app.

