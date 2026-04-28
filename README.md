# Documentation Engine Template

This repository is a **consumer documentation template** for product teams using the shared Documentation Engine Lib from `Ascertia-Integrations/documentation-engine-lib`.

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

If your existing docs come from a GitBook-style repository, use the importer script in this template to bootstrap the `docs/` tree, then do a focused cleanup pass for any GitBook-specific formatting that should not remain in this project.

#### When to use this migration flow

Use this flow when:

- the source repository is organized like a GitBook docs repo
- the source uses `README.md`, `SUMMARY.md`, or `.gitbook/assets/`
- you want this template to become the new home for the docs content
- you want release branches named `X.Y.Z` to continue driving published Docusaurus versions

#### Prerequisites and repo expectations

- run the command from the root of this template repository
- point `<gitbook-source-dir>` at the root of the source GitBook-style repository
- the importer reads `.gitbook.yaml` when present and honors `root`, `structure.readme`, and `structure.summary`
- if `.gitbook.yaml` is missing, the importer defaults to:
  - docs root: `.`
  - readme file: `README.md`
  - summary file: `SUMMARY.md`
- the source content should be Markdown or MDX based and use normal GitBook file conventions
- for a first migration into this starter template, prefer `--force-clean --reset-versioned-docs`
- if you plan to migrate release branches too, run `git fetch --prune` in the source repo first so the remote-tracking branch list is current
- `--migrate-version-branches` requires a clean worktree in the target repo because the script creates or updates target release branches and commits imported content there

#### What the importer handles automatically

Structure and navigation:

- resolves the import root from `.gitbook.yaml` `root`
- uses `.gitbook.yaml` `structure.readme` and `structure.summary` when present
- imports from the resolved docs root instead of assuming the repo root is the docs root
- renames section landing pages such as `README.md`, `README.mdx`, or `README.markdown` to matching `index.*` files
- parses `SUMMARY.md` entries into `sidebar_label`, `sidebar_position`, and generated `_category_.json` files
- adds `slug: /` for the imported site landing page when the root `README` becomes `index.*`
- preserves existing frontmatter fields when they already exist instead of overwriting them

Links, assets, and MDX safety:

- rewrites relative Markdown links between imported docs into project-relative doc links
- rewrites Markdown links and image references that point at `.gitbook/assets/...`
- rewrites HTML `src` references on tags such as `<img>` and `<source>` when they point at GitBook-managed assets
- copies `.gitbook/assets/` into `static/img/gitbook/`
- copies non-Markdown files found under the resolved docs root alongside the imported docs
- normalizes void HTML tags such as `<img>`, `<source>`, `<br>`, and `<hr>` into MDX-safe self-closing tags

GitBook block translation:

- converts GitBook hint blocks into Docusaurus admonitions
- uses this style mapping:
  - `info -> info`
  - `success -> tip`
  - `warning -> warning`
  - `danger -> danger`
- converts GitBook `{% content-ref url="..." %}` blocks into normal Markdown links

Cleanup and versioning support:

- skips control and hidden paths such as `SUMMARY.md`, `book.json`, and dot-prefixed content under the docs root
- optionally removes stale `versions.json`, `versioned_docs/`, and `versioned_sidebars/` with `--reset-versioned-docs`
- optionally migrates source release branches named `X.Y.Z` into matching target repo branches with `--migrate-version-branches`
- prunes stale target release branches that are no longer present in the source release branch set
- creates one local commit per migrated release branch import
- logs resolved paths, rewritten links, generated categories, skipped control files, copied assets, and import totals

Release-version follow-up handled by version sync:

- when release docs are later generated with `docusaurus-sync-version`, the version-sync pipeline rewrites `/img/gitbook/...` image references inside versioned docs into local MDX imports
- this means the GitBook asset copy under `static/img/gitbook/` is used during import, and the versioned output is later normalized again for Docusaurus versioned docs

#### What still needs manual translation

The importer handles the structural conversion, but you should still review the migrated content for GitBook-specific patterns that need a project-native Docusaurus equivalent.

Callouts and notices:

GitBook style:

```md
{% hint style="warning" %}
Review this setting before you upgrade.
{% endhint %}
```

This project style:

```mdx
:::warning
Review this setting before you upgrade.
:::
```

Content references:

GitBook style:

```md
{% content-ref url="getting-started/README.md" %}
[Getting started](getting-started/README.md)
{% endcontent-ref %}
```

This project style:

```mdx
[Getting started](./getting-started/index.mdx)
```

Section landing pages:

GitBook style:

```text
getting-started/
  README.md
  install.md
```

This project style:

```text
docs/
  getting-started/
    index.mdx
    install.mdx
```

Navigation ordering:

GitBook style:

```md
* [Getting started](getting-started/README.md)
  * [Install](getting-started/install.md)
```

This project style:

```mdx
---
sidebar_position: 1
---
```

```json
{
  "label": "Getting Started",
  "position": 1
}
```

Shared uploaded images:

GitBook style:

```md
![Architecture](.gitbook/assets/architecture.png)
```

This project style:

```mdx
![Architecture](/img/gitbook/architecture.png)
```

If the image should become a long-term shared site asset, move it into `static/img/` and update the reference to its final path there.

Page-local images:

GitBook style:

```md
![Step screenshot](../.gitbook/assets/install-step.png)
```

This project style:

```mdx
![Step screenshot](./assets/install-step.png)
```

Use a nearby `assets/` folder when the image only belongs to one page or one small section.

Collapsible sections:

GitBook style:

```md
<details>
<summary>Advanced setup</summary>

Extra steps
</details>
```

This project style:

```mdx
<details>
  <summary>Advanced setup</summary>

  Extra steps
</details>
```

Grouped or tabbed content:

GitBook style:

```md
{% tabs %}
{% tab title="Cloud" %}
Cloud steps
{% endtab %}
{% tab title="Self-hosted" %}
Self-hosted steps
{% endtab %}
{% endtabs %}
```

This project style:

```mdx
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs>
  <TabItem value="cloud" label="Cloud" default>
    Cloud steps
  </TabItem>
  <TabItem value="self-hosted" label="Self-hosted">
    Self-hosted steps
  </TabItem>
</Tabs>
```

Embeds and raw HTML:

GitBook style:

```md
{% embed url="https://example.com/demo" %}
```

This project style:

```mdx
<iframe
  src="https://example.com/demo"
  title="Demo"
  width="100%"
  height="480"
  loading="lazy"
/>
```

If an embed does not render cleanly in MDX, replace it with a normal link, screenshot, or a project-specific React component instead of keeping unsupported GitBook syntax.

#### Command recipes by migration scenario

First import into the starter template:

```bash
bash ./scripts/import-gitbook.sh --force-clean --reset-versioned-docs ../legacy-gitbook ./docs
```

Replace starter `docs/` content but leave versioned artifacts alone:

```bash
bash ./scripts/import-gitbook.sh --force-clean ../legacy-gitbook ./docs
```

Replace starter `docs/` content and clear stale versioned artifacts:

```bash
bash ./scripts/import-gitbook.sh --force-clean --reset-versioned-docs ../legacy-gitbook ./docs
```

Enable detailed debug logging during the import:

```bash
bash ./scripts/import-gitbook.sh --verbose --force-clean ../legacy-gitbook ./docs
```

Reduce output to warnings and errors only:

```bash
bash ./scripts/import-gitbook.sh --quiet --force-clean ../legacy-gitbook ./docs
```

Import current docs and matching release branches named `X.Y.Z`:

```bash
bash ./scripts/import-gitbook.sh --force-clean --reset-versioned-docs --migrate-version-branches ../legacy-gitbook ./docs
```

Practical rule: for a first migration into this starter template, usually start with `--force-clean --reset-versioned-docs`. Add `--migrate-version-branches` only when the source repository also uses release branches named `X.Y.Z`.

#### Version-branch behavior

When `--migrate-version-branches` is enabled:

- only source branches that match `X.Y.Z` are treated as release branches
- the script checks both local and remote-tracking source branches and prefers a local branch when both exist
- stale target release branches that are no longer present in the source release branch set are pruned automatically
- each imported release branch is created or updated in an isolated worktree and committed locally
- the current-docs import also runs in an isolated worktree so your checked-out branch stays clean after the run
- if the target repository has uncommitted changes, branch migration stops before making branch updates

#### Post-import validation checklist

After the import completes, confirm that:

- the migrated docs landed under `docs/`
- root landing pages became `index.*`
- sidebar order and labels look correct in the generated site
- `_category_.json` files were generated where you expect section categories
- GitBook-managed uploads now exist under `static/img/gitbook/`
- imported links and images render correctly in Docusaurus
- stale `versions.json`, `versioned_docs/`, and `versioned_sidebars/` were removed when you used `--reset-versioned-docs`
- any leftover GitBook-specific embeds, tab syntax, or raw HTML were cleaned up manually

#### Troubleshooting and common pitfalls

- Old starter pages still show up after import:
  Re-run with `--force-clean --reset-versioned-docs`.
- A release branch was not migrated:
  Make sure the source branch name matches `X.Y.Z` exactly, then run `git fetch --prune` in the source repo and try again.
- Branch migration aborts because the worktree is dirty:
  Commit or stash changes in the target repo before using `--migrate-version-branches`.
- An image looks wrong in versioned docs:
  Confirm the source asset was imported into `static/img/gitbook/`; version sync expects those files to exist when it rewrites release docs.
- A GitBook block is still present after import:
  The importer only rewrites supported patterns. Use the translation examples above for the remaining manual cleanup pass.
- Hidden dot-path content did not import:
  The importer skips hidden files and directories under the docs root by design.

Reference:

- Docusaurus Markdown features: [https://docusaurus.io/docs/markdown-features](https://docusaurus.io/docs/markdown-features)
- Docusaurus links: [https://docusaurus.io/docs/markdown-features/links](https://docusaurus.io/docs/markdown-features/links)
- Docusaurus assets and images: [https://docusaurus.io/docs/markdown-features/assets](https://docusaurus.io/docs/markdown-features/assets)

## What this template gives you

- A Docusaurus site with docs served from `docs/`
- Shared styling and layout through `@ascertia-integrations/docusaurus-preset-docs`
- GitHub Pages deployment through `.github/workflows/deploy-docs.yml`
- Automatic version syncing for release branches such as `1.2.3`
- A working example of the files the Documentation Engine expects to exist

## How to use this template

1. Create a new repository from this template.
2. Update the product-specific files listed in [What you should change](#what-you-should-change).
3. Keep the platform contract in place as described in [What you should not change without understanding the impact](#what-you-should-not-change-without-understanding-the-impact).
4. Enable GitHub Pages for the repository in **Settings → Pages** and set the source to **GitHub Actions**.
5. Add the required GitHub secret `DOCS_PLATFORM_NPM_TOKEN`.
6. Push to `main` for current docs, and to release branches named `X.Y.Z` for versioned docs.

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

These files are part of the contract with the Documentation Engine and should stay aligned with the shared library/workflow:

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

This repository is the **consumer**. The `Ascertia-Integrations/documentation-engine-lib` repository is the **platform/library**.

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

Enable GitHub Pages for the repository in **Settings → Pages** and set the source to **GitHub Actions**.

If a deploy from a release branch such as `2.0.6` is blocked, check **Settings → Environments → `github-pages`**. GitHub Pages custom workflows use the `github-pages` environment by default, and that environment may restrict which branches or tags are allowed to deploy.

What to check:

- Review **Deployment branches and tags** or any branch restriction rules on the `github-pages` environment.
- If the environment only allows `main` or `master`, release branches named `X.Y.Z` will be blocked from deploying.

Choose the behavior you want:

- Deploy only from `main`: keep the environment restriction and only run the Pages deploy workflow on `main`.
- Allow release branches to deploy: add the relevant release branch names or patterns such as `*.*.*` to the allowed branches and tags for the `github-pages` environment.
- Use tags or releases instead of branch deploys: update the environment rule to match that release process.

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
