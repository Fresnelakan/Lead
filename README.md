# Projet Lead : Application d'Optimisation d'Emploi du Temps Étudiant

## Description du Projet

Lead est une application développée avec Flutter visant à aider les étudiants à optimiser leur emploi du temps. En se basant sur le planning saisi par l'utilisateur, l'application utilise une intelligence artificielle (Google Gemini) via une Cloud Function Firebase pour identifier les temps libres et suggérer des activités pertinentes, notamment des sessions de révision pour favoriser l'apprentissage constant et la productivité.

Le projet utilise Firebase comme plateforme backend pour l'authentification, la base de données (Firestore) et l'exécution de code côté serveur (Cloud Functions).

## Fonctionnalités Implémentées (Prototype Actuel)

Le prototype actuel, pleinement fonctionnel dans l'environnement de développement local (Web + Firebase Emulators), permet de démontrer les fonctionnalités clés suivantes :

1.  **Authentification :** Connexion des utilisateurs (actuellement testée avec e-mail/mot de passe).
2.  **Saisie de l'Emploi du Temps :** L'utilisateur peut saisir son emploi du temps hebdomadaire via une interface dédiée.
3.  **Envoi des Données à Firestore :** L'emploi du temps saisi est sauvegardé dans la base de données Firestore (collection `user_timetables`).
4.  **Déclenchement de l'Optimisation :** L'écriture de l'emploi du temps dans Firestore déclenche automatiquement une Cloud Function.
5.  **Optimisation par IA (Gemini) :** La Cloud Function appelle l'API Google Gemini pour analyser l'emploi du temps, identifier les créneaux libres et générer des suggestions d'activités (révision, apprentissage, etc.).
6.  **Enregistrement du Résultat Optimisé :** Le planning optimisé et enrichi par l'IA est sauvegardé dans Firestore (collection `optimized_schedules`).
7.  **Affichage de l'Emploi du Temps Optimisé :** L'application écoute les changements dans Firestore et affiche le planning optimisé et les suggestions de l'IA dans une section dédiée(Page "optimisé" 4ème onlget en partant de la gauche sdasn le bottom bar).

## Technologies Utilisées

* **Frontend :** Flutter (avec Dart)
* **Backend :** Firebase
    * Firebase Authentication
    * Cloud Firestore
    * Cloud Functions (avec Node.js)
* **Intelligence Artificielle :** Google Gemini API

*(Note : Le cahier des charges initial proposait un backend Django et de l'IA embarquée/OR-Tools, mais l'implémentation actuelle utilise Firebase/Cloud Functions/Gemini API pour des raisons de rapidité de développement et d'intégration de l'IA générative).*

## Configuration et Exécution (Mode Développement - Web + Émulateurs Locaux)

Pour exécuter le projet dans l'environnement de développement local, vous aurez besoin des éléments suivants :

### Prérequis

* Flutter SDK installé et configuré.
* Firebase CLI installé (`npm install -g firebase-tools`).
* Node.js installé (pour les Cloud Functions).
* Un projet Firebase créé (même un projet gratuit) et connecté à votre projet Flutter (`flutterfire configure`).
* Une clé API Google Gemini.

### Étapes de Configuration

1.  **Clonez le dépôt :**
    ```bash
    git clone [URL_DU_DEPOT]
    cd lead
    ```
    *(Remplacez `[URL_DU_DEPOT]` par l'URL réelle de votre dépôt Git).*

2.  **Installez les dépendances Flutter :**
    ```bash
    flutter pub get
    ```

3.  **Installez les dépendances des Cloud Functions :**
    Naviguez dans le répertoire `functions` et installez les dépendances Node.js.
    ```bash
    cd functions
    npm install
    cd .. # Retournez à la racine du projet Flutter
    ```

4.  **Configurez la clé API Gemini pour les Cloud Functions :**
    Votre clé API Gemini doit être stockée de manière sécurisée. Exécutez la commande suivante depuis le répertoire `functions` (ou la racine si votre `firebase.json` est configuré ainsi) :
    ```bash
    firebase functions:config:set gemini.api_key="VOTRE_CLE_API_GEMINI"
    ```
    *(Remplacez `"VOTRE_CLE_API_GEMINI"` par votre clé API Gemini réelle. N'ajoutez jamais votre clé API directement dans le code source !)*

### Exécution du Projet

1.  **Démarrez les émulateurs Firebase :**
    Dans le terminal, depuis la racine de votre projet, lancez les émulateurs nécessaires.
    ```bash
    firebase emulators:start --only "functions,firestore,auth,ui" --debug
    ```
    Laissez ce terminal ouvert. L'adresse de l'interface utilisateur des émulateurs est généralement `http://localhost:4000`. Vous pouvez l'ouvrir dans votre navigateur pour visualiser les données Firestore, les logs des fonctions, etc.

2.  **Lancez l'application Flutter sur le Web :**
    Dans un **nouveau** terminal, depuis la racine de votre projet, lancez l'application en ciblant Chrome.
    ```bash
    flutter run -d chrome
    ```
    L'application devrait s'ouvrir dans un nouvel onglet de votre navigateur.

### Utilisation de l'Application (via Navigateur + Émulateurs)

1.  **Authentification :** Dans l'application ouverte dans le navigateur, utilisez l'écran d'authentification. Créez un nouveau compte ou connectez-vous. L'authentification se fait via l'émulateur Authentication. (Note : Les e-mails de réinitialisation de mot de passe s'afficheront dans les logs du terminal des émulateurs, pas dans une vraie boîte mail).
2.  **Saisie de l'Emploi du Temps :** Naviguez vers la section de saisie de l'emploi du temps. Remplissez les informations de votre planning.
3.  **Soumission :** Soumettez l'emploi du temps. Cela déclenchera l'écriture dans l'émulateur Firestore.
4.  **Observation de l'Optimisation :**
    * Regardez le terminal où les émulateurs tournent : vous devriez voir les logs indiquant que la Cloud Function `optimizeSchedule` est déclenchée et s'exécute.
    * Dans l'UI de l'émulateur Firestore (`http://localhost:4000/firestore`), vous verrez le document s'ajouter dans `user_timetables` et, après l'exécution réussie de la fonction, un document s'ajouter/modifier dans `optimized_schedules`.
5.  **Affichage du Résultat :** Naviguez dans l'application web vers la page de l'emploi du temps optimisé. Le planning généré par l'IA devrait s'afficher.

## Prochaines Étapes et Défis

* Finaliser le test et la stabilisation de l'application sur les appareils Android physiques (problèmes de connectivité avec les émulateurs en cours d'investigation).
* Affiner le prompt de l'API Gemini pour améliorer la pertinence des suggestions d'activités.
* Implémenter les fonctionnalités supplémentaires prévues (notifications, etc.).
* Préparer le déploiement de l'application et des Cloud Functions sur Firebase en ligne pour une version de production (nécessitera le plan Blaze pour la Cloud Function utilisant Gemini).

## Contributeurs

* AKAN Fresnel
* BATOKO Chahidath
* MAZOU Marzouk

---
