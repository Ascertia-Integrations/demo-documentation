---
sidebar_position: 1
title: MDX Examples
---

This page demonstrates a few common MDX features.

## Admonitions

:::note
This is a note.
:::

:::warning
This is a warning.
:::

## Code blocks

```bash
npm run build
```

## Tabs

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs>
  <TabItem value="npm" label="npm" default>

```bash
npm install
npm start
```

  </TabItem>
  <TabItem value="ci" label="CI">

```text
Push to main → deploy current docs
Push to X.Y.Z → sync version → deploy
```

  </TabItem>
</Tabs>
