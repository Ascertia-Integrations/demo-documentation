# Demo Documentation (Consumer Repo Template)

This repository is a sample **consumer documentation repo** that uses the shared Docs Platform tooling.

## Use this as a template

- Create a new repo from this template.
- Update `docusaurus.config.ts` (title, logo, and any product-specific navbar/footer items).
- Add a repo (or org) secret named `DOCS_PLATFORM_NPM_TOKEN` containing a PAT with `read:packages` so CI can install the platform packages from GitHub Packages.

## What this repo implements

- Docusaurus site at the repo root (`docs/`, `docusaurus.config.ts`, `sidebars.ts`).
- Shared preset/theme: `@ascertia-integrations/docusaurus-preset-docs`.
- Version sync CLI: `@ascertia-integrations/docusaurus-version-sync` (bin: `docusaurus-sync-version`).
- GitHub Pages deployment via the platform reusable workflow: `.github/workflows/deploy-docs.yml`.

## Local development

```bash
npm install
npm start
```

## Versioning model (branches → Docusaurus versions)

- `main` contains the current/unreleased docs (`docs/`).
- Release branches named `X.Y.Z` (example: `1.0.0`) are treated as released documentation versions.
- On pushes to `X.Y.Z`, CI syncs that branch into Docusaurus version artifacts on `main`:
  - `versions.json`
  - `versioned_docs/`
  - `versioned_sidebars/`

## Local version sync (optional)

```bash
npm run sync-version -- 1.0.0 --allow-dirty
```

## Notes

- `docusaurus.config.ts` reads `SITE_URL` and `BASE_URL` (set by CI) so GitHub Pages deployments don’t require hardcoding.
