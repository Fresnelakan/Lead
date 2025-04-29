// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const functions = require("firebase-functions");

// The Firebase Admin SDK to access Firestore.
const admin = require("firebase-admin");
admin.initializeApp();

// Importez la bibliothèque pour l'API Gemini (vous l'avez déjà installée)
const {GoogleGenerativeAI} = require("@google/generative-ai");
const { onDocumentWritten } = require("firebase-functions/firestore");

// --- Configuration sécurisée de la clé API Gemini ---
// Vous devez configurer la clé API Gemini de manière sécurisée.
// Exécutez cette commande dans votre terminal DEPUIS le répertoire 'functions':
// firebase functions:config:set gemini.api_key="VOTRE_CLE_API_GEMINI"
// Remplacez "VOTRE_CLE_API_GEMINI" par votre clé API réelle.
// N'incluez JAMAIS votre clé API directement dans le code source.
const apiKey = functions.config().gemini.api_key;
const genAI = new GoogleGenerativeAI(apiKey);
// --- Fin de la configuration sécurisée ---


// La Cloud Function qui sera déclenchée par les écritures dans Firestore
const firestore = admin.firestore();
exports.optimizeSchedule = onDocumentWritten(
  {
      document: "user_timetables/{userId}", // Le chemin du document
      // region: "europe-west1", // Ajoutez la région si votre fonction est déployée dans une région spécifique
  },
  async (event) => {
      const userId = event.params.userId;
      // Accédez aux données avec event.data?.after?.data() dans la nouvelle API
      const timetableData = event.data?.after?.data();

      if (!timetableData) {
          console.log("No data associated with the event");
          return null;
      }

      console.log(`Optimizing schedule for user: ${userId}`);
      console.log("Received timetable data:", JSON.stringify(timetableData));

      try {
          // --- Début de l'appel à l'API Gemini ---
          const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"}); // Votre modèle Gemini

          // Construisez le prompt
          const prompt = `Optimize the following schedule (provided as JSON) by identifying free time slots and suggesting relevant self-improvement activities for those slots. Return the complete optimized schedule as a JSON object with the exact same structure as the input, but with added activities in the free time slots. Input Schedule JSON: ${JSON.stringify(timetableData)}`;

          const result = await model.generateContent(prompt);
          const response = await result.response;

          // Parser la réponse JSON de Gemini
          const optimizedScheduleJsonString = response.text();
          const optimizedScheduleData = JSON.parse(optimizedScheduleJsonString);
          // --- Fin de l'appel à l'API Gemini ---

          console.log("Optimized schedule data received from Gemini:", optimizedScheduleData);

          // Écrire l'emploi du temps optimisé dans la collection 'optimized_schedules'
          const optimizedScheduleRef = admin.firestore().collection("optimized_schedules").doc(userId);
          await optimizedScheduleRef.set(optimizedScheduleData);

          console.log(`Optimized schedule saved to Firestore for user: ${userId}`);

          return null; // Fin de l'exécution de la fonction
      } catch (error) {
          console.error("Error optimizing schedule:", error);
          return null;
      }
  }
);