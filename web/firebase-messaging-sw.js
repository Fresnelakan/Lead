// web/firebase-messaging-sw.js

// Importation des SDK Firebase nécessaires
// Assurez-vous d'utiliser les versions qui correspondent à votre package 'firebase' dans pubspec.yaml
// Si vous utilisez une version plus récente de Firebase sur Flutter, ajustez les versions ici.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

// Votre configuration Firebase (celle que vous avez fournie)
const firebaseConfig = {
  apiKey: "AIzaSyA7XRK0FPlz_7jyUHqj2xY8Ue_SMf9xHOg",
  authDomain: "lead-10402.firebaseapp.com",
  projectId: "lead-10402",
  storageBucket: "lead-10402.appspot.com",
  messagingSenderId: "796388366674",
  appId: "1:796388366674:web:19b619d3aba6156ca8828b"
};

// Initialisation de Firebase
firebase.initializeApp(firebaseConfig);

// Obtenir l'instance de Messaging
const messaging = firebase.messaging();

// Gérer les messages en arrière-plan (quand l'application est fermée ou en arrière-plan)
// C'est ici que le Service Worker reçoit les notifications et les affiche
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Reçu un message en arrière-plan ', payload);

  // Personnalisation de la notification qui sera affichée à l'utilisateur
  const notificationTitle = payload.notification.title || 'Nouvelle notification';
  const notificationOptions = {
    body: payload.notification.body || 'Vous avez un nouveau message.',
    icon: '/favicon.png', // Chemin vers l'icône de votre application. Assurez-vous qu'elle existe !
    data: payload.data, // Les données personnalisées peuvent être incluses ici
    // Vous pouvez ajouter d'autres options comme des actions, des images, etc.
    // actions: [{ action: 'open_url', title: 'Ouvrir' }],
    // image: 'URL_DE_VOTRE_IMAGE',
  };

  // Afficher la notification
  // `self.registration.showNotification` est l'API standard pour afficher une notification via un Service Worker
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Gérer les clics sur les notifications (facultatif mais recommandé pour une meilleure UX)
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Clic sur la notification :', event.notification.tag, event.notification.data);
  event.notification.close(); // Ferme la notification après le clic

  const customData = event.notification.data; // Récupère les données que vous avez passées

  // Ici, vous pouvez définir ce qui se passe après le clic
  // Par exemple, ouvrir un nouvel onglet ou focus sur un onglet existant
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Vérifier si une fenêtre de votre application est déjà ouverte
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url.includes(self.location.origin)) { // Vérifier que l'URL correspond à votre application
          client.focus(); // Focus sur l'onglet existant
          // Si vous avez besoin de naviguer vers une page spécifique dans l'app ouverte
          if (customData && customData.page) {
            client.postMessage({ type: 'NAVIGATE', page: customData.page });
          }
          return;
        }
      }
      // Si aucune fenêtre n'est ouverte, ouvrir une nouvelle fenêtre/onglet
      let urlToOpen = self.location.origin + '/'; // L'URL de base de votre application Flutter Web
      if (customData && customData.page) {
        // Si vous voulez naviguer vers une page spécifique à l'ouverture
        // Adaptez ceci à votre logique de routage Flutter Web
        urlToOpen += `?page=${customData.page}`;
      }
      clients.openWindow(urlToOpen);
    })
  );
});

// Important: Ce Service Worker doit être servi depuis le dossier 'web' de votre projet Flutter.
// Quand vous exécutez 'flutter run -d chrome' ou 'flutter build web',
// Flutter s'assure que ce fichier est correctement déployé.
