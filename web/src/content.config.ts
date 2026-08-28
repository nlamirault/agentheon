import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// Agent profiles live at the repo root in ../agents, OUTSIDE the Astro app,
// so they stay copy-pasteable and act as the single source of truth.
const agents = defineCollection({
  loader: glob({ pattern: '**/*.md', base: '../agents' }),
  schema: z.object({
    name: z.string(),
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

export const collections = { agents };
