// Satteri hast plugin that rewrites relative `.md` links inside docs/ markdown
// so they resolve on the built site instead of 404-ing:
//   - doc -> doc            ->  /docs/<slug>/       (matches the docs collection ids)
//   - agents/<x>/README.md  ->  /agents/<x>/        (the existing agent pages)
//   - anything else in-repo ->  GitHub blob URL     (team/*, CONTRIBUTING, ...)
// Only markdown sourced from ../docs is touched; agent profiles are left alone.
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DOCS_ROOT = path.resolve('../docs');
const REPO_ROOT = path.resolve('..');
const GH_BLOB = 'https://github.com/nlamirault/agentheon/blob/main';

const inDocs = (abs) => abs === DOCS_ROOT || abs.startsWith(DOCS_ROOT + path.sep);
const toPosix = (p) => p.split(path.sep).join('/');

/** Absolute path of a docs file OR directory -> its site URL, mirroring the
 *  collection id (README collapses to its directory; the docs root -> overview). */
function docHref(abs, hash) {
  let slug = toPosix(path.relative(DOCS_ROOT, abs))
    .replace(/\/$/, '') // trailing slash on directory links
    .replace(/\.md$/, '');
  if (slug === '' || slug === 'README') slug = 'overview';
  else slug = slug.replace(/\/README$/, '');
  return `/docs/${slug}/${hash}`;
}

/** Absolute path of any other in-repo file -> agent page or GitHub blob URL. */
function repoHref(abs, hash) {
  const rel = toPosix(path.relative(REPO_ROOT, abs));
  const agent = rel.match(/^agents\/([^/]+)\/README\.md$/);
  if (agent) return `/agents/${agent[1]}/${hash}`;
  return `${GH_BLOB}/${rel}${hash}`;
}

/** @type {import('satteri').HastPluginDefinition} */
const docLinks = {
  name: 'agentheon-doc-links',
  element: {
    filter: ['a'],
    visit(node, ctx) {
      const href = node.properties?.href;
      if (typeof href !== 'string') return;
      if (/^(https?:|mailto:|tel:|#|\/)/.test(href)) return; // external / anchor / already absolute
      const [rel, frag] = href.split('#');
      if (!rel || !ctx.fileURL) return; // pure "#anchor" or no source
      const source = fileURLToPath(ctx.fileURL);
      if (!inDocs(source)) return; // only rewrite links authored in docs/
      const hash = frag ? `#${frag}` : '';
      const target = path.resolve(path.dirname(source), rel);
      ctx.setProperty(node, 'href', inDocs(target) ? docHref(target, hash) : repoHref(target, hash));
    },
  },
};

export default docLinks;
