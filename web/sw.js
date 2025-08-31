// Service Worker for Gravel First PWA
// Version 1.0.0

const CACHE_NAME = 'gravel-first-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.ico',
  '/favicon.svg',
  '/web-app-manifest-192x192.png',
  '/web-app-manifest-512x512.png'
];

// Install event - cache essential resources
self.addEventListener('install', function(event) {
  console.log('[SW] Installing service worker');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {
        console.log('[SW] Caching essential resources');
        return cache.addAll(urlsToCache);
      })
      .catch(function(error) {
        console.warn('[SW] Cache installation failed:', error);
      })
  );
  // Force activation of new service worker
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', function(event) {
  console.log('[SW] Activating service worker');
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  // Take control of all pages immediately
  self.clients.claim();
});

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', function(event) {
  // Only handle GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // Skip cross-origin requests and chrome-extension requests
  if (!event.request.url.startsWith(self.location.origin) || 
      event.request.url.startsWith('chrome-extension://')) {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then(function(response) {
        // Return cached version if available
        if (response) {
          return response;
        }

        // Otherwise fetch from network
        return fetch(event.request).then(function(response) {
          // Don't cache if not a valid response
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // Clone the response for caching
          const responseToCache = response.clone();

          caches.open(CACHE_NAME)
            .then(function(cache) {
              cache.put(event.request, responseToCache);
            });

          return response;
        });
      })
      .catch(function(error) {
        console.warn('[SW] Fetch failed:', error);
        // You could return a fallback page here
        throw error;
      })
  );
});

// Handle messages from the main thread
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Received skip waiting message');
    self.skipWaiting();
  }
});
