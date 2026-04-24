import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const defaultOrg = 'Ascertia-Integrations';
const defaultRepo = 'documentation-engine-template';

const ghRepo = process.env.GITHUB_REPOSITORY;
const [organizationName, projectName] = ghRepo ? ghRepo.split('/', 2) : [defaultOrg, defaultRepo];

const siteUrl = process.env.SITE_URL ?? 'http://localhost:3000';
const baseUrl = process.env.BASE_URL ?? '/';

const config: Config = {
  title: 'Documentation Engine Template',
  tagline: 'Starter documentation site using the shared Documentation Engine Lib',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: siteUrl,
  baseUrl,

  organizationName,
  projectName,

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      '@ascertia-integrations/docusaurus-preset-docs',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: '/',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      },
    ],
  ],

  themeConfig: {
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Documentation Engine Template',
      logo: {
        alt: 'Documentation Engine Template Logo',
        src: 'img/logo.svg',
      },
    },

    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
