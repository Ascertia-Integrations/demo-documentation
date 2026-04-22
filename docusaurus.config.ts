import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const defaultOrg = 'Ascertia-Integrations';
const defaultRepo = 'demo-documentation';

const ghRepo = process.env.GITHUB_REPOSITORY;
const [organizationName, projectName] = ghRepo ? ghRepo.split('/', 2) : [defaultOrg, defaultRepo];

const siteUrl = process.env.SITE_URL ?? 'http://localhost:3000';
const baseUrl = process.env.BASE_URL ?? '/';

const config: Config = {
  title: 'Demo Documentation',
  tagline: 'Sample docs site using the shared docs platform',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: siteUrl,
  baseUrl,

  organizationName,
  projectName,

  onBrokenLinks: 'throw',

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
          editUrl: `https://github.com/${organizationName}/${projectName}/tree/main/`,
          routeBasePath: '/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
          },
          editUrl: `https://github.com/${organizationName}/${projectName}/tree/main/`,
          onInlineTags: 'warn',
          onInlineAuthors: 'warn',
          onUntruncatedBlogPosts: 'warn',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Demo Documentation',
      logo: {
        alt: 'Demo Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Tutorial',
        },
        {to: '/blog', label: 'Blog', position: 'left'},
        {type: 'docsVersionDropdown', position: 'right'},
        {
          href: `https://github.com/${organizationName}/${projectName}`,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },

    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
