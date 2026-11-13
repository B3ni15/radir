// Radír landing: a statikus oldalt az ASSETS szolgálja ki, ez a Worker csak a várólistát kezeli.
// POST /api/waitlist  { email, website }  → a címet a WAITLIST KV-ba teszi (kulcs: kisbetűs e-mail).
// Exportálás: npx wrangler kv key list --binding WAITLIST --remote

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json; charset=utf-8' } });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/api/waitlist') return env.ASSETS.fetch(request);
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
  },
};
