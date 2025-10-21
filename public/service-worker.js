// CardMind Service Worker
const CACHE_NAME = 'cardmind-v1.0.0';

// 需要缓存的静态资源
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icons/icon-72x72.svg',
  '/icons/icon-96x96.svg',
  '/icons/icon-128x128.svg',
  '/icons/icon-144x144.svg',
  '/icons/icon-152x152.svg',
  '/icons/icon-192x192.svg',
  '/icons/icon-384x384.svg',
  '/icons/icon-512x512.svg',
  '/icons/maskable-icon-512x512.svg'
];

// 安装阶段：预缓存静态资源
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Service Worker: Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// 激活阶段：清理旧缓存
self.addEventListener('activate', (event) => {
  const cacheWhitelist = [CACHE_NAME];
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (!cacheWhitelist.includes(cacheName)) {
              console.log('Service Worker: Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => self.clients.claim())
  );
});

// 请求拦截：使用缓存优先策略
self.addEventListener('fetch', (event) => {
  // 只处理GET请求
  if (event.request.method !== 'GET') {
    return;
  }

  // 对不同资源使用不同的缓存策略
  const url = new URL(event.request.url);
  
  // 处理API请求（网络优先，失败时回退到缓存）
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirst(event.request));
  } 
  // 处理静态资源（缓存优先，失败时回退到网络）
  else {
    event.respondWith(cacheFirst(event.request));
  }
});

// 缓存优先策略
async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const networkResponse = await fetch(request);
    
    // 只缓存成功的GET请求
    if (networkResponse.ok && request.method === 'GET') {
      // 克隆响应，因为响应流只能使用一次
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    // 如果是HTML请求，返回离线页面
    if (request.headers.get('accept')?.includes('text/html')) {
      return caches.match('/index.html');
    }
    
    throw error;
  }
}

// 网络优先策略
async function networkFirst(request) {
  try {
    const networkResponse = await fetch(request);
    
    // 如果请求成功，更新缓存
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    // 网络请求失败时，尝试从缓存获取
    const cachedResponse = await caches.match(request);
    
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // 如果缓存中也没有，返回错误响应
    return new Response('网络连接失败，且无缓存数据可用', {
      status: 408,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}

// 后台同步支持
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-cards') {
    event.waitUntil(syncCardsData());
  }
});

// 处理后台同步任务
async function syncCardsData() {
  // 这里可以实现将本地更改同步到服务器的逻辑
  // 实际实现会根据应用需求定制
  console.log('Service Worker: Performing background sync');
}

// 推送通知支持
self.addEventListener('push', (event) => {
  if (!event.data) return;
  
  try {
    const data = event.data.json();
    
    const options = {
      body: data.body,
      icon: '/icons/icon-192x192.svg',
      badge: '/icons/icon-72x72.svg',
      data: {
        url: data.url || '/' // 点击通知时打开的URL
      }
    };
    
    event.waitUntil(
      self.registration.showNotification(data.title, options)
    );
  } catch (error) {
    console.error('Service Worker: Error processing push notification:', error);
  }
});

// 处理通知点击
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  const urlToOpen = event.notification.data?.url || '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // 如果已有打开的窗口，直接导航
        for (const client of clientList) {
          if (client.url === urlToOpen && 'focus' in client) {
            return client.focus();
          }
        }
        // 否则打开新窗口
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

// 消息处理
self.addEventListener('message', (event) => {
  // 接收来自主线程的消息
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// 周期性同步支持（需要特殊权限）
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'periodic-sync-cards') {
    event.waitUntil(syncCardsData());
  }
});