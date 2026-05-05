# Open Feelings — web

Static landing site for [openfeelings.finklea.dev](https://openfeelings.finklea.dev) and
[/privacy](https://openfeelings.finklea.dev/privacy). SvelteKit + adapter-static, deployed to
Cloudflare Pages.

The privacy page mirrors the user-facing portion of `../docs/release/privacy-policy-draft.md`.
Internal sections from the markdown draft (App Store Connect mapping, Apple Review notes,
open-questions checklist) are intentionally NOT published.

## Develop

```sh
pnpm install
pnpm dev          # http://localhost:5173
pnpm build        # static output in build/
pnpm preview      # http://localhost:4173 (serves build/)
pnpm check        # svelte-check + tsc
```

Theme is light/dark via `prefers-color-scheme` only — toggle macOS Appearance to test.

## Regenerate the OG image

```sh
swift scripts/generate-og.swift
```

Writes `static/og-image.png` (1200×630) using CoreGraphics with the warm-calm palette.
Run after touching the wordmark or palette.

## Deploy to Cloudflare Pages

### One-time: connect the repo

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**.
2. Select `open-feelings-ios`.
3. Settings:
   - Project name: `openfeelings`
   - Production branch: `main` (or whichever branch should auto-deploy)
   - Framework preset: **SvelteKit**
   - Build command: `cd web && pnpm install --frozen-lockfile && pnpm build`
   - Build output directory: `web/build`
   - Root directory: leave blank (commands above already cd into `web/`)
   - Environment variables: `NODE_VERSION=20`
4. **Save and Deploy**. Cloudflare clones the repo, runs the build, and serves the result at
   `<project>.pages.dev`.

### One-time: add the custom domain

1. Pages project → **Custom domains** → **Set up a custom domain** → enter
   `openfeelings.finklea.dev`.
2. If `finklea.dev` is in the same Cloudflare account, Cloudflare auto-creates the CNAME and
   provisions a Universal SSL cert (~1 minute).
3. Verify: `curl -sI https://openfeelings.finklea.dev` returns `HTTP/2 200` with a `cf-ray:`
   header.

### Subsequent deploys

Push to the production branch. Cloudflare builds and deploys automatically.

### Emergency CLI deploy

For a one-off push without going through git:

```sh
pnpm build
pnpm dlx wrangler pages deploy build --project-name=openfeelings
```

## Update the privacy policy

The user-facing copy on `/privacy` lives in `src/routes/privacy/+page.svelte`. The canonical
internal source is `../docs/release/privacy-policy-draft.md`. When the draft changes:

1. Update the markdown draft.
2. Mirror the user-facing portion (lines 1–93 of the draft) into `+page.svelte`.
3. Update the effective date metadata.
4. Build, preview, push.
