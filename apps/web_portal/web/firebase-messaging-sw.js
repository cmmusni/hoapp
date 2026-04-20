// Firebase Cloud Messaging Service Worker for HOApp Web Portal
// This handles background push notifications when the browser tab is not in focus.

// Give the service worker access to Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker.
// TODO: Replace with your Firebase project config (same values as firebase_options.dart)
firebase.initializeApp({
  apiKey: "AIzaSyDXdCxJvi4UjWdFdCIF26qsAjd-VNZjJtQ",
  authDomain: "hoapp-db.firebaseapp.com",
  projectId: "hoapp-db",
  storageBucket: "hoapp-db.firebasestorage.app",
  messagingSenderId: "431525120566",
  appId: "1:431525120566:web:adbb03f24fd20310cbe697",
  measurementId: "G-8FSQWJN5KM"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message:', payload);

  const notificationTitle = payload.notification?.title || 'HOApp';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click:', event);
  event.notification.close();

  const url = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus();
          client.navigate(url);
          return;
        }
      }
      // Otherwise open a new window
      return clients.openWindow(url);
    })
  );
});
