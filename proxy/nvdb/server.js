import express from 'express';
import morgan from 'morgan';
import fetch from 'node-fetch';

const app = express();
const PORT = process.env.PORT || 8080;

// Configuration
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || '*'; // e.g., https://gravel-first.web.app
const NVDB_BASE = 'https://nvdb2012.trafikverket.se';

// Basic CORS middleware (adjust ALLOWED_ORIGIN in production)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }
  next();
});

app.use(morgan('combined'));

// Input validation helpers
function isValidBbox(bbox) {
  // bbox format: west,south,east,north
  const parts = (bbox || '').split(',').map(Number);
  if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) return false;
  const [w, s, e, n] = parts;
  if (w < -180 || w > 180 || e < -180 || e > 180) return false;
  if (s < -90 || s > 90 || n < -90 || n > 90) return false;
  // limit area ~ 2 degrees max span to prevent abuse
  if (Math.abs(e - w) > 2 || Math.abs(n - s) > 2) return false;
  return true;
}

// Proxy endpoint for NVDB road surface (objekt 97)
app.get('/api/v2/objekt/97', async (req, res) => {
  try {
    const { bbox, srid = '4326', format = 'json', inkludera = 'egenskaper,geometri' } = req.query;

    if (!isValidBbox(bbox)) {
      return res.status(400).json({ error: 'Invalid bbox' });
    }
    if (srid !== '4326') {
      return res.status(400).json({ error: 'Only srid=4326 is allowed' });
    }
    if (format !== 'json') {
      return res.status(400).json({ error: 'Only format=json is allowed' });
    }

    const url = new URL(`${NVDB_BASE}/api/v2/objekt/97`);
    url.searchParams.set('bbox', bbox);
    url.searchParams.set('srid', srid);
    url.searchParams.set('format', format);
    url.searchParams.set('inkludera', inkludera);

    const resp = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'User-Agent': 'GravelFirst NVDB Proxy/1.0 (+https://example.com)'
      },
      redirect: 'follow',
    });

    // Forward status and body
    res.setHeader('Cache-Control', 'public, max-age=600'); // 10 min cache
    res.status(resp.status);
    const text = await resp.text();
    return res.send(text);
  } catch (err) {
    console.error('Proxy error:', err);
    return res.status(502).json({ error: 'Bad gateway' });
  }
});

app.get('/healthz', (req, res) => res.json({ status: 'ok' }));

app.listen(PORT, () => {
  console.log(`NVDB proxy listening on ${PORT}`);
});
