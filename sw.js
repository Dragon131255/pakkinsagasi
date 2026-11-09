// ホーム画面から開いたとき用。通信できるときは常に最新を取りに行き、圏外のときだけ保存した分を使う
var CACHE = 'pakkinsagasi-v28';
var FILES = ['./', 'index.html', 'search.js', 'data/oring_jis_b2401.csv', 'data/sakagami_hydraulic.csv', 'data/dust_seal.csv', 'data/wear_ring.csv', 'images/sky-piston.png', 'images/sky-rod.png', 'images/ky-piston.png', 'images/ky-rod.png', 'images/uhp-piston.png', 'images/mlp-piston.png', 'images/mlr-rod.png', 'images/uph-piston.png', 'images/uph-rod.png', 'images/sdr-rod.png', 'images/lbh-rod.png', 'images/dhs-rod.png', 'images/dki-rod.png', 'images/sw-piston.png', 'images/swa-piston.png', 'images/swb-piston.png', 'images/swo-piston.png', 'images/wr-piston.png', 'images/wpl-piston.png', 'images/wpg-piston.png', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png'];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(FILES); }));
  self.skipWaiting();
});

self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (keys) {
    return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }));
  self.clients.claim();
});

self.addEventListener('fetch', function (e) {
  if (e.request.method !== 'GET') return;
  e.respondWith(fetch(e.request, { cache: 'no-cache' }).then(function (res) {
    // 正常な応答だけ保存する（公開作業中の 404 などで、保存済みの正しいファイルを上書きしない）
    if (res.ok) {
      var copy = res.clone();
      caches.open(CACHE).then(function (c) { c.put(e.request, copy); });
    }
    return res;
  }).catch(function () {
    return caches.match(e.request, { ignoreSearch: true }).then(function (hit) {
      return hit || new Response('圏外のため読み込めません。電波のある場所で開き直してください。', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    });
  }));
});
