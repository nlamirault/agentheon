import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// Agent profiles live at the repo root in ../agents, OUTSIDE the Astro app,
// so they stay copy-pasteable and act as the single source of truth. Each agent
// is a directory (agents/<name>/README.md) with its vendored skills alongside in
// agents/<name>/skills/; the loader matches only the README and strips the
// suffix so the collection id stays the bare agent name (e.g. `zeus`).
const agents = defineCollection({
  loader: glob({
    pattern: '*/README.md',
    base: '../agents',
    generateId: ({ entry }) => entry.replace(/\/README\.md$/, ''),
  }),
  schema: z.object({
    name: z.string(),
    aliases: z.array(z.string()).default([]),
    title: z.string(),
    domain: z.string(),
    emoji: z.string(),
    color: z.string(),
    model: z.string(),
    tools: z.array(z.string()),
    tagline: z.string(),
    order: z.number().default(99),
    reasoning: z.enum(['low', 'medium', 'high']).optional(),
    tone: z.string().optional(),
    handoffs: z.array(z.string()).default([]),
    does: z.array(z.string()).default([]),
    does_not: z.array(z.string()).default([]),
    skills: z.array(z.string()).default([]),
  }),
});

// Documentation lives at the repo root in ../docs, OUTSIDE the Astro app, so it
// stays readable on GitHub and acts as the single source of truth (same deal as
// agents/). Diátaxis-structured (tutorials/how-to/reference/explanation) plain
// markdown with no frontmatter — titles are parsed from the H1 at build time
// (see lib/docs.ts). Decisions (ADRs) are intentionally excluded. README files
// collapse to their directory slug so URLs stay clean:
//   docs/README.md              -> id "overview"
//   docs/tutorials/README.md    -> id "tutorials"
//   docs/reference/agents.md    -> id "reference/agents"
const docs = defineCollection({
  loader: glob({
    pattern: ['**/*.md', '!decisions/**'],
    base: '../docs',
    generateId: ({ entry }) => {
      const slug = entry.replace(/\.md$/, '');
      if (slug === 'README') return 'overview';
      return slug.replace(/\/README$/, '');
    },
  }),
});

export const collections = { agents, docs };
