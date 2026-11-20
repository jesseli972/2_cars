// Network-first: always get the latest version when online, fall back to the cached copy offline.
const C = '2cars-v17';
const F = ['./', 'index.html', 'manifest.webmanifest', 'icon-180.png', 'icon-192.png', 'icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(C).then(c => c.addAll(F)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== C).map(x => caches.delete(x)))));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  // only the game's own files; leaderboard requests always go straight to the network
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then(res => {
        const copy = res.clone();
        caches.open(C).then(c => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request).then(r => r || caches.match('index.html')))
  );
});

// Chat push notifications
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data.json(); } catch (_) { d = { title: '2 Cars', body: e.data ? e.data.text() : 'New message' }; }
  e.waitUntil(self.registration.showNotification(d.title || '2 Cars', {
    body: d.body || 'New message',
    icon: 'icon-192.png',
    badge: 'icon-192.png',
    data: { url: d.url || './#chat' },
  }));
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
    for (const c of list) {
      if ('focus' in c) { c.postMessage({ type: 'open-chat' }); return c.focus(); }
    }
    return self.clients.openWindow(e.notification.data.url);
  }));
});
