const BASE = import.meta.env.BASE_URL;

/** Join the site base path with a relative path, avoiding double/missing slashes. */
export function withBase(path = ''): string {
  const base = BASE.replace(/\/$/, ''); // strip trailing slash
  const rel = path.replace(/^\//, ''); // strip leading slash
  return rel ? `${base}/${rel}` : `${base}/`;
}
