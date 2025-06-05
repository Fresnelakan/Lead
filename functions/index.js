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
      console.log("Received timetable data:", timetableData);

      try {
        // --- Début de l'appel à l'API Gemini (votre code existant) ---
        const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"}); // Votre modèle Gemini

        // Construisez le prompt (votre code existant)
        // Construisez le prompt amélioré pour les étudiants et la productivité/révision
        const prompt = `You are an AI assistant for students, designed to help optimize their weekly schedules for productivity and constant learning. Analyze the following student schedule (provided as JSON) to identify free time slots. For these free slots, suggest specific, relevant self-improvement activities that align with student goals, such as:
        - Revising courses or specific subjects from the week's schedule.
        - Practicing exercises related to recent lessons.
        - Reading academic papers or supplementary material.
        - Working on personal projects related to studies.
        - Engaging in online learning platforms (e.g., Coursera, edX) relevant to their field.
        - Planning the next study sessions.

        The suggested activities should be concrete and actionable. Prioritize academic-related tasks, especially reviewing subjects from the provided schedule.

        Return the complete optimized schedule as a JSON object. The structure must be exactly the same as the input JSON, but with new activities added in the identified free time slots. Each activity entry should ideally include a brief 'note' field if additional context (like specific subject to review) is helpful.

        Input Schedule JSON: ${JSON.stringify(timetableData)}`;

        
        const result = await model.generateContent(prompt);
        const response = await result.response;

        // --- Début du NOUVEAU traitement de la réponse de Gemini (remplace l'ancien JSON.parse) ---
        let optimizedScheduleJsonString = response.text();

        console.log("Raw response text from Gemini:", response.text()); // Utile pour le débogage

        // Nettoyer la réponse: Supprimer les marqueurs de bloc de code Markdown si présents
        // On cherche la première occurrence de ```json et la dernière occurrence de ```
        const jsonStart = optimizedScheduleJsonString.indexOf('```json');
        const jsonEnd = optimizedScheduleJsonString.lastIndexOf('```');

        if (jsonStart !== -1 && jsonEnd !== -1 && jsonEnd > jsonStart) {
            // Extraire la chaîne JSON entre les marqueurs
            optimizedScheduleJsonString = optimizedScheduleJsonString.substring(jsonStart + '```json'.length, jsonEnd).trim();
        } else if (optimizedScheduleJsonString.startsWith('```') && optimizedScheduleJsonString.endsWith('```')) {
             // Cas où c'est juste ```...``` sans le 'json'
             optimizedScheduleJsonString = optimizedScheduleJsonString.substring('```'.length, optimizedScheduleJsonString.length - '```'.length).trim();
        }
        // Vous pourriez ajouter d'autres cas de nettoyage si Gemini renvoie d'autres formats inattendus

        console.log("Cleaned JSON string for parsing:", optimizedScheduleJsonString); // Utile pour le débogage

        let optimizedScheduleData;
        // Tenter de parser la réponse JSON nettoyée
        try {
            optimizedScheduleData = JSON.parse(optimizedScheduleJsonString);
        } catch (parseError) {
            console.error("Failed to parse JSON after cleaning:", parseError);
            console.error("String that caused parsing error:", optimizedScheduleJsonString); // Afficher la chaîne qui a échoué le parsing
            // Vous pouvez choisir de relancer l'erreur ici ou de la gérer silencieusement
            // Relancer l'erreur fera échouer la fonction, ce qui est souvent souhaitable en cas de problème majeur
            throw new Error("Failed to parse Gemini response as valid JSON after cleaning.");
        }
        // --- Fin du NOUVEAU traitement de la réponse de Gemini ---


        console.log("Optimized schedule data received from Gemini (parsed):", optimizedScheduleData); // Utile pour le débogage

        // Écrire l'emploi du temps optimisé dans la collection 'optimized_schedules'
        const optimizedScheduleRef = admin.firestore().collection("optimized_schedules").doc(userId);
        await optimizedScheduleRef.set(optimizedScheduleData);

        console.log(`Optimized schedule saved to Firestore for user: ${userId}`);

        return null; // Indique le succès de la fonction (ou la fin du traitement)
    } catch (error) {
        // Ce catch gère les erreurs générales de la fonction (y compris celles relancées par le catch interne)
        console.error("An error occurred during optimizeSchedule execution:", error);
        // Vous pouvez enregistrer l'erreur en base de données ou faire autre chose si nécessaire
        return null; // Indique que la fonction a terminé (avec une erreur gérée)
    }
}
);