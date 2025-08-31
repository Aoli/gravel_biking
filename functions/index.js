import functions from 'firebase-functions';

const NVDB_BASE = 'https://nvdb2012.trafikverket.se';
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || '*';

function isValidBbox(bbox) {
  const parts = (bbox || '').split(',').map(Number);
  if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) return false;
  const [w, s, e, n] = parts;
  if (w < -180 || w > 180 || e < -180 || e > 180) return false;
  if (s < -90 || s > 90 || n < -90 || n > 90) return false;
  if (Math.abs(e - w) > 2 || Math.abs(n - s) > 2) return false;
  return true;
}

export const nvdbProxy = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.set('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  res.set('Vary', 'Origin');
  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const { bbox, srid = '4326', format = 'json', inkludera = 'egenskaper,geometri' } = req.query;

    if (!isValidBbox(bbox)) return res.status(400).json({ error: 'Invalid bbox' });
    if (srid !== '4326') return res.status(400).json({ error: 'Only srid=4326 is allowed' });
    if (format !== 'json') return res.status(400).json({ error: 'Only format=json is allowed' });

    const url = new URL(`${NVDB_BASE}/api/v2/objekt/97`);
    url.searchParams.set('bbox', bbox);
    url.searchParams.set('srid', srid);
    url.searchParams.set('format', format);
    url.searchParams.set('inkludera', inkludera);

    const resp = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'User-Agent': 'GravelFirst NVDB Proxy/1.0 (+https://gravel-first.app)',
        'Accept': 'application/json, text/plain;q=0.5',
      },
      redirect: 'follow',
    });

    res.set('Cache-Control', 'public, max-age=600');
    const upstreamType = resp.headers.get('content-type') || 'application/json; charset=utf-8';
    res.set('Content-Type', upstreamType);
    res.status(resp.status);
    const text = await resp.text();
    return res.send(text);
  } catch (err) {
    console.error('Functions nvdbProxy error:', err);
    return res.status(502).json({ error: 'Bad gateway' });
  }
});
