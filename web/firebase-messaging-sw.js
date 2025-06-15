// web/firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyA7XRK0FPlz_7jyUHqj2xY8Ue_SMf9xHOg",
  authDomain: "lead-10402.firebaseapp.com",
  projectId: "lead-10402",
  storageBucket: "lead-10402.appspot.com",
  messagingSenderId: "796388366674",
  appId: "1:796388366674:web:19b619d3aba6156ca8828b"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();