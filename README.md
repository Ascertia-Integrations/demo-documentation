# Demo Documentation Template

This repository is a **consumer documentation template** for product teams using the shared Docs Platform from `Ascertia-Integrations/docusaurus-github-pages-poc`.

Use it as the starting point for a new documentation repository, then replace the demo branding and demo content with your own product documentation.

## For documentation writers

If you are writing docs content, you will spend most of your time in `docs/`. In normal cases, you do not need to touch the build workflow, the shared preset, or the generated versioned files.

### Where to write

- create pages in `docs/`
- use `.mdx` for new pages
- use `index.mdx` when a folder should become a section landing page
- keep related pages together in folders

Example structure:

```text
docs/
  index.mdx
  nested-section/
    index.mdx
    demo-1.mdx
    demo-2.mdx
```

### Basic page syntax

Pages use Markdown with MDX support.

Example file: `docs/nested-section/demo-3.mdx`

```mdx
---
sidebar_position: 3
---

# Nested Section Demo 3

This is a new page in the nested section.

- It uses normal Markdown
- It appears in the sidebar because it lives in `docs/`
- Its order in the sidebar is controlled by `sidebar_position`
```

Useful front matter fields:

- `title`: page title
- `sidebar_position`: ordering in the sidebar
- `slug`: custom URL when needed, for example `slug: /getting-started`

### Images

You have two good options:

- for page-specific images, place them next to the doc that uses them, or in a nearby `assets/` folder
- for shared site assets such as logos or reusable images, place them in `static/img/`

Example of a shared image from `static/img/`, used inside a doc page:

```mdx
![Shared logo](/img/logo.svg)
```

If a page has its own image, keep it close to the page and link to it relatively.

Example file layout:

```text
docs/
  nested-section/
    index.mdx
    assets/
      architecture.png
```

Example inside `docs/nested-section/index.mdx`:

```mdx
![Architecture diagram](./assets/architecture.png)
```

### Links

For links between docs, prefer relative file links. This is the safest option for versioned documentation.

Example inside `docs/index.mdx`:

```mdx
[Nested section landing page](./nested-section/index.mdx)
[Demo page inside the section](./nested-section/demo-1.mdx)
[External link](https://docusaurus.io/docs/markdown-features)
```

Use external URLs only for external sites. For links to another page in this docs repo, prefer file links over hardcoded site paths.

### Writer rules of thumb

- keep product content inside `docs/`
- use short folders and clear filenames
- prefer relative file links between docs
- keep screenshots and diagrams close to the page that uses them unless they are shared across many pages
- do not edit `versions.json`, `versioned_docs/`, or `versioned_sidebars/` by hand

### Importing GitBook content

If your existing docs come from a GitBook-style repository, use the importer script in this template to bootstrap the `docs/` tree.

Basic usage:

```bash
bash ./scripts/import-gitbook.sh ../legacy-gitbook ./docs
```

Replace existing `docs/` content first:

```bash
bash ./scripts/import-gitbook.sh --force-clean ../legacy-gitbook ./docs
```

Replace existing `docs/` content and clear stale starter/versioned artifacts:

```bash
bash ./scripts/import-gitbook.sh --force-clean --reset-versioned-docs ../legacy-gitbook ./docs
```

Enable detailed debug logs during the import:

```bash
bash ./scripts/import-gitbook.sh --verbose --force-clean ../legacy-gitbook ./docs
```

Reduce output to warnings and errors only:

```bash
bash ./scripts/import-gitbook.sh --quiet --force-clean ../legacy-gitbook ./docs
```

What the importer handles:

- `.gitbook.yaml` `root`, `readme`, and `summary` settings
- GitBook-managed uploaded images from `.gitbook/assets/`, copied into `docs/assets/gitbook/`
- `README.md` or `README.mdx` section landing pages, converted to `index.md` or `index.mdx`
- `SUMMARY.md` ordering and labels, converted into Docusaurus sidebar metadata
- optional cleanup of stale `versions.json`, `versioned_docs/`, and `versioned_sidebars/`
- relative Markdown links between imported docs
- rewritten Markdown image and link references that point at `.gitbook/assets/...`
- copied assets alongside the imported content

What the logs show:

- resolved source and destination paths
- detected GitBook config and summary file handling
- skipped control files such as `SUMMARY.md`
- warnings if stale versioned docs artifacts still exist after import
- copied assets and imported documents
- rewritten internal links
- applied or skipped frontmatter fields
- generated `_category_.json` files
- final import counts

Practical rule: for a first migration into a starter Docusaurus repo, prefer `--force-clean --reset-versioned-docs` so old starter pages do not keep showing through versioned artifacts. After that, review the generated docs for any GitBook-specific embeds or formatting that still need manual cleanup.

Reference:

- Docusaurus Markdown features: [https://docusaurus.io/docs/markdown-features](https://docusaurus.io/docs/markdown-features)
- Docusaurus links: [https://docusaurus.io/docs/markdown-features/links](https://docusaurus.io/docs/markdown-features/links)
- Docusaurus assets and images: [https://docusaurus.io/docs/markdown-features/assets](https://docusaurus.io/docs/markdown-features/assets)

## What this template gives you

- A Docusaurus site with docs served from `docs/`
- Shared styling and layout through `@ascertia-integrations/docusaurus-preset-docs`
- GitHub Pages deployment through `.github/workflows/deploy-docs.yml`
- Automatic version syncing for release branches such as `1.2.3`
- A working example of the files the Docs Platform expects to exist

## How to use this template

1. Create a new repository from this template.
2. Update the product-specific files listed in [What you should change](#what-you-should-change).
3. Keep the platform contract in place as described in [What you should not change without understanding the impact](#what-you-should-not-change-without-understanding-the-impact).
4. Add the required GitHub secret `DOCS_PLATFORM_NPM_TOKEN`.
5. Push to `main` for current docs, and to release branches named `X.Y.Z` for versioned docs.

## What you should change

These files are expected to be owned by the consumer repository:

- `docs/`
  Replace the demo Markdown and MDX content with your product documentation.
- `docusaurus.config.ts`
  Update the site `title`, `tagline`, navbar title, logo, social card, `defaultOrg`, and `defaultRepo`.
- `static/img/`
  Replace the demo logo, favicon, and social/share images.
- `src/css/custom.css`
  Adjust consumer-specific styling if needed.
- `package.json`
  Update the package `name` and any scripts you intentionally want to add for this repo.

You can also remove demo-only starter assets if they are no longer used, for example:

- `src/pages/markdown-page.mdx`
- `src/components/HomepageFeatures/`
- unused images under `static/img/`

## What you should not change without understanding the impact

These files are part of the contract with the Docs Platform and should stay aligned with the shared library/workflow:

- `.github/workflows/deploy-docs.yml`
  This calls the reusable deployment workflow from the platform repo. Only change the referenced workflow version intentionally when upgrading the platform.
- `.npmrc`
  This points the `@ascertia-integrations` scope to GitHub Packages.
- `@ascertia-integrations/docusaurus-preset-docs` in `package.json`
  This is the shared preset that provides the common Docusaurus setup.
- `siteUrl` and `baseUrl` environment handling in `docusaurus.config.ts`
  These are intentionally read from `SITE_URL` and `BASE_URL` so GitHub Pages works correctly in CI.
- `sidebars.ts`
  Keep this file present unless you also adjust the version-sync setup to point somewhere else.

Do not manually edit these generated version artifacts:

- `versions.json`
- `versioned_docs/`
- `versioned_sidebars/`

Those files are managed by the version-sync flow and committed as build artifacts for released documentation versions.

## How this repository interacts with the library

This repository is the **consumer**. The `Ascertia-Integrations/docusaurus-github-pages-poc` repository is the **platform/library**.

The interaction points are:

- Preset package: `@ascertia-integrations/docusaurus-preset-docs`
  The consumer repo uses this in `docusaurus.config.ts` to inherit shared docs behavior, styling, and defaults.
- Version sync CLI: `docusaurus-sync-version`
  CI uses the platform workflow to fetch and run the latest sync CLI so versioned docs artifacts stay in sync.
- Reusable GitHub Actions workflow:
  `.github/workflows/deploy-docs.yml` delegates build and deployment to the platform repo workflow.

Practical rule: product teams should mostly work in `docs/`, branding assets, and light consumer configuration. Shared behavior should be changed in the platform repo, not copied into each consumer repo.

## Versioning model

- `main` contains the current or unreleased documentation from `docs/`
- release branches named `X.Y.Z` are treated as released documentation versions
- when CI runs on a release branch, it syncs that branch into the generated version files: `versions.json`, `versioned_docs/`, and `versioned_sidebars/`

Before running local install or version-sync commands, make sure your machine can authenticate to GitHub Packages for the `@ascertia-integrations` scope. The repository-level `DOCS_PLATFORM_NPM_TOKEN` secret is only used in CI.

If you need to test version syncing locally, run this from the repository root after local GitHub Packages authentication is configured:

```bash
npx --yes @ascertia-integrations/docusaurus-version-sync@latest 1.0.0 --allow-dirty
```

## Required GitHub configuration

Add this repository secret:

- `DOCS_PLATFORM_NPM_TOKEN`
  It should be a PAT with `read:packages`. If packages or workflows are private, it will usually also need `repo`.

About the token:

- use a GitHub **Personal access token (classic)**
- give it at least `read:packages`
- if the package is private or repo-scoped, it will usually also need `repo`

This repository already includes the required npm scope configuration in `.npmrc`:

```ini
@ascertia-integrations:registry=https://npm.pkg.github.com
```

## Local development

Before installing dependencies locally, authenticate your machine to GitHub Packages for the `@ascertia-integrations` scope.

From the repository root, set up local access with your GitHub **Personal access token (classic)**:

```bash
export DOCS_PLATFORM_NPM_TOKEN=github_pat_...
npm config set //npm.pkg.github.com/:_authToken "$DOCS_PLATFORM_NPM_TOKEN"
npm install
```

Practical rule: if `npm install` fails with a package authentication error, the token is missing, expired, or does not have the required scopes.

After that, from the repository root, start the site locally:

```bash
npm start
```

From the repository root, build the site:

```bash
npm run build
```

## Working model for teams

- Write product documentation in `docs/`
- Keep repo-specific branding and navigation in `docusaurus.config.ts`
- Let the platform repo own shared deployment logic and shared Docusaurus behavior
- Avoid editing generated version artifacts by hand
- If you need new shared functionality, add it to the platform repo and consume it here
