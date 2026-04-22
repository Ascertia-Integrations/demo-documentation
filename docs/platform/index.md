---
sidebar_position: 1
title: Platform Overview
slug: /
---

This consumer repo follows the **branch-driven versioning** model:

- `main`: current/unreleased docs (`docs/`)
- `X.Y.Z` branches: released docs sources (example: `1.0.0`)

CI syncs `X.Y.Z` branches into Docusaurus version artifacts on `main`:

- `versions.json`
- `versioned_docs/`
- `versioned_sidebars/`
