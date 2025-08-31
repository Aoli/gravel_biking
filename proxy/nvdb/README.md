# NVDB CORS Proxy (Cloud Run)

A minimal proxy to access Trafikverket NVDB from the web app with CORS, validation, and caching.

## Deploy

1) Build & deploy to Cloud Run (adjust project/region):

```bash
# From this folder
gcloud builds submit --tag gcr.io/PROJECT_ID/nvdb-proxy

gcloud run deploy nvdb-proxy \
  --image gcr.io/PROJECT_ID/nvdb-proxy \
  --platform managed \
  --region REGION \
  --allow-unauthenticated \
  --set-env-vars ALLOWED_ORIGIN=https://YOUR_WEB_APP_HOST
```

Optionally put Cloud CDN/Load Balancer in front.

## Configure app

Build the Flutter web app with the proxy base URL:

```bash
flutter build web \
  --dart-define=NVDB_PROXY_BASE=https://nvdb-proxy-xxxx-uc.a.run.app
```

During development:

```bash
flutter run -d chrome \
  --dart-define=NVDB_PROXY_BASE=http://localhost:8080
```

## Notes

- Restricts bbox size to ~2 degrees per axis to reduce abuse.
- Only allows srid=4326 and format=json.
- Sets CORS headers; lock ALLOWED_ORIGIN to your domain in prod.
- Adds Cache-Control: max-age=600 (10 min).
