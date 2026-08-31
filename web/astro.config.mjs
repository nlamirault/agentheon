// @ts-check
import { defineConfig } from 'astro/config';
import { satteri } from '@astrojs/markdown-satteri';

import docLinks from './src/lib/doc-links.mjs';

// Served at the domain root on Cloudflare Workers (see ADR-0002). No `base`
// path — asset URLs resolve from `/`, not a `/agentheon` project subpath.
export default defineConfig({
  site: 'https://agentheon.lamirault.xyz',
  markdown: {
    // Astro 7's default Markdown processor (Satteri) with one extra hast plugin
    // that rewrites relative .md links in docs/ so they resolve on the site.
    processor: satteri({ hastPlugins: [docLinks] }),
  },
});
