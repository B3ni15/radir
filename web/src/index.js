// Radír landing: a statikus oldalt az ASSETS szolgálja ki, ez a Worker
// - a várólistát kezeli (POST /api/waitlist → WAITLIST KV, kulcs: kisbetűs e-mail),
// - a robots.txt-t és a sitemap.xml-t a mostani domainre generálja,
// - a HTML-ben a data-abs jelölt címeket abszolút URL-re cseréli (Discord, Facebook csak ilyet tölt be).
// Domaintől független: workers.dev-en és saját domainen is jó.
// Exportálás: npx wrangler kv key list --binding WAITLIST --remote

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const PAGES = ['/', '/adatvedelem/'];

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json; charset=utf-8' } });

const text = (body, type) => new Response(body, { headers: { 'content-type': `${type}; charset=utf-8`, 'cache-control': 'public, max-age=3600' } });

async function waitlist(request, env) {
  if (request.method !== 'POST') return json({ error: 'method' }, 405);
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ error: 'invalid' }, 400);
  }
  // a „website” mező rejtett csapda: ember nem tölti ki, a robotok igen
  if (data?.website) return json({ ok: true });

  const email = String(data?.email ?? '').trim().toLowerCase();
  if (email.length > 254 || !EMAIL.test(email)) return json({ error: 'email' }, 400);

  // ugyanaz a cím többször: nem hiba, de nem írjuk felül az első jelentkezés idejét
  if (!(await env.WAITLIST.get(email))) {
    await env.WAITLIST.put(email, JSON.stringify({ at: new Date().toISOString() }));
  }
  return json({ ok: true });
}

// a JSON-LD-ben a {{ORIGIN}} helyére a domain kerül (a szöveg több darabban is jöhet)
class LdJson {
  constructor(origin) { this.origin = origin; this.buf = ''; }
  text(chunk) {
    this.buf += chunk.text;
    if (chunk.lastInTextNode) {
      chunk.replace(this.buf.replaceAll('{{ORIGIN}}', this.origin), { html: true });
      this.buf = '';
    } else chunk.remove();
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { origin, pathname } = url;

    if (pathname === '/api/waitlist') return waitlist(request, env);
    if (pathname === '/robots.txt') {
      return text(`User-agent: *\nAllow: /\nDisallow: /api/\n\nSitemap: ${origin}/sitemap.xml\n`, 'text/plain');
    }
    if (pathname === '/sitemap.xml') {
      const urls = PAGES.map((p) => `  <url><loc>${origin}${p}</loc></url>`).join('\n');
      return text(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`, 'application/xml');
    }

    const res = await env.ASSETS.fetch(request);
    if (!(res.headers.get('content-type') ?? '').includes('text/html')) return res;
    return new HTMLRewriter()
      .on('[data-abs]', {
        element(el) {
          for (const attr of ['content', 'href']) {
            const v = el.getAttribute(attr);
            if (v?.startsWith('/')) el.setAttribute(attr, origin + v);
          }
          el.removeAttribute('data-abs');
        },
      })
      .on('script[type="application/ld+json"]', new LdJson(origin))
      .transform(res);
  },
};
