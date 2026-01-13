import { defineConfig } from 'astro/config';

import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://jeffrey0117.github.io',
  base: '/Evernote',

  markdown: {
    shikiConfig: {
      theme: 'github-light',
      wrap: true
    }
  },

  integrations: [sitemap()]
});