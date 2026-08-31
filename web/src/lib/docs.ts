// Helpers for the `docs` collection. Docs carry no frontmatter, so title and
// summary are derived from the raw markdown body, and category from the id path.

export interface DocCategory {
  key: string;
  label: string;
  blurb: string;
}

/** Diátaxis quadrants, in reading order. `overview` is the docs root README. */
export const DOC_CATEGORIES: DocCategory[] = [
  {
    key: 'overview',
    label: 'Overview',
    blurb: 'Start here — what Agentheon is and where the docs live.',
  },
  {
    key: 'tutorials',
    label: 'Tutorials',
    blurb: 'Learning-oriented. Take a first task through the pantheon, step by step.',
  },
  {
    key: 'how-to',
    label: 'How-to guides',
    blurb: 'Goal-oriented. Solve a specific problem — install, add an agent, and more.',
  },
  {
    key: 'reference',
    label: 'Reference',
    blurb: 'Information-oriented. The catalog and profile schema, for quick lookup.',
  },
  {
    key: 'explanation',
    label: 'Explanation',
    blurb: 'Understanding-oriented. Why the pantheon is shaped the way it is.',
  },
];

const QUADRANTS = new Set(['tutorials', 'how-to', 'reference', 'explanation']);

/** Diátaxis category key from a doc id (its first path segment; else overview). */
export function docCategory(id: string): string {
  const seg = id.split('/')[0];
  return QUADRANTS.has(seg) ? seg : 'overview';
}

/** Human label for a category key. */
export function categoryLabel(key: string): string {
  return DOC_CATEGORIES.find((c) => c.key === key)?.label ?? key;
}

/** First `# H1` from the raw markdown body, falling back to the id. */
export function docTitle(body: string | undefined, id: string): string {
  const m = body?.match(/^#\s+(.+?)\s*$/m);
  return m ? m[1].trim() : id;
}

/** First real paragraph of the body, with markdown links flattened to text. */
export function docSummary(body = ''): string {
  const lines = body.replace(/<!--[\s\S]*?-->/g, '').split('\n');
  const para: string[] = [];
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) {
      if (para.length) break;
      continue;
    }
    if (/^#{1,6}\s/.test(line)) continue; // heading
    if (/^>/.test(line)) continue; // blockquote (the Diátaxis tag line)
    if (/^[-*]\s/.test(line)) {
      if (para.length) break;
      continue;
    }
    para.push(
      line
        .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1') // links -> text
        .replace(/`([^`]+)`/g, '$1') // inline code
        .replace(/\*\*([^*]+)\*\*/g, '$1') // bold
        .replace(/\*([^*]+)\*/g, '$1'), // italic
    );
  }
  return para.join(' ');
}
