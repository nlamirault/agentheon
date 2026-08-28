// @ts-check
import { defineConfig } from 'astro/config';

// Served at the domain root on Cloudflare Workers (see ADR-0002). No `base`
// path — asset URLs resolve from `/`, not a `/agentheon` project subpath.
export default defineConfig({
  site: 'https://agentheon.lamirault.xyz',
});
