// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const functions = require("firebase-functions");

// The Firebase Admin SDK to access Firestore.
const admin = require("firebase-admin");
admin.initializeApp();

// Importez la bibliothèque pour l'API Gemini (vous l'avez déjà installée)
const {GoogleGenerativeAI} = require("@google/generative-ai");
// Importe les triggers Firestore pour la version V1 des fonctions (si vous utilisez V2, l'import sera différent)
const { onDocumentWritten } = require("firebase-functions/firestore");

// --- Configuration sécurisée de la clé API Gemini ---
// Vous devez configurer la clé API Gemini de manière sécurisée.
// Exécutez cette commande dans votre terminal DEPUIS le répertoire 'functions':
// firebase functions:config:set gemini.api_key="VOTRE_CLE_API_GEMINI"
// Remplacez "VOTRE_CLE_API_GEMINI" par votre clé API réelle.
// N'incluez JAMAIS votre clé API directement dans le code source.
const apiKey = functions.config().gemini.api_key;

// Vérifiez si l'API Key est définie au démarrage (important pour les émulateurs locaux)
if (!apiKey) {
    throw new Error("Gemini API key is not configured. Set it with: firebase functions:config:set gemini.api_key='YOUR_API_KEY'");
}

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
        // Accédez aux données avec event.data?.after?.data() dans la nouvelle API (pour les triggers V1/V2)
        const timetableData = event.data?.after?.data();

        if (!timetableData) {
            console.log("No data associated with the event");
            return null;
        }

        // Correction des template literals : utilisez les backticks (`)
        console.log(`Optimizing schedule for user: ${userId}`);
        console.log("Received timetable data:", JSON.stringify(timetableData));
        console.log("Received timetable data:", timetableData);

        try {
            // --- Début de l'appel à l'API Gemini (votre code existant) ---
            const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"}); // Votre modèle Gemini

            // Construisez le prompt (votre code existant)
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
            
            console.log("Prompt sent to Gemini:", prompt); // Ajout d'un log pour le prompt

            const result = await model.generateContent(prompt);
            const response = await result.response;

            // --- Début du NOUVEAU traitement de la réponse de Gemini ---
            let optimizedScheduleJsonString = response.text();

            console.log("Raw response text from Gemini:", response.text()); // Utile pour le débogage

            // Nettoyer la réponse: Supprimer les marqueurs de bloc de code Markdown si présents
            // Correction des chaînes pour les backticks (```)
            const jsonStartMarker = "```json";
            const codeBlockEndMarker = "```";

            const jsonStartIndex = optimizedScheduleJsonString.indexOf(jsonStartMarker);
            const jsonEndIndex = optimizedScheduleJsonString.lastIndexOf(codeBlockEndMarker);

            if (jsonStartIndex !== -1 && jsonEndIndex !== -1 && jsonEndIndex > jsonStartIndex) {
                // Extraire la chaîne JSON entre les marqueurs
                optimizedScheduleJsonString = optimizedScheduleJsonString.substring(jsonStartIndex + jsonStartMarker.length, jsonEndIndex).trim();
            } else if (optimizedScheduleJsonString.startsWith(codeBlockEndMarker) && optimizedScheduleJsonString.endsWith(codeBlockEndMarker)) {
                // Cas où c'est juste ```...``` sans le 'json' après le premier triple backtick
                optimizedScheduleJsonString = optimizedScheduleJsonString.substring(codeBlockEndMarker.length, optimizedScheduleJsonString.length - codeBlockEndMarker.length).trim();
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
                // Relancer l'erreur fera échouer la fonction, ce qui est souvent souhaitable en cas de problème majeur
                throw new Error("Failed to parse Gemini response as valid JSON after cleaning.");
            }
            // --- Fin du NOUVEAU traitement de la réponse de Gemini ---


            console.log("Optimized schedule data received from Gemini (parsed):", optimizedScheduleData); // Utile pour le débogage

            // Écrire l'emploi du temps optimisé dans la collection 'optimized_schedules'
            const optimizedScheduleRef = admin.firestore().collection("optimized_schedules").doc(userId);
            await optimizedScheduleRef.set(optimizedScheduleData);

            console.log(`Optimized schedule saved to Firestore for user: ${userId}`); // Correction du template literal

            return null; // Indique le succès de la fonction (ou la fin du traitement)
        } catch (error) {
            // Ce catch gère les erreurs générales de la fonction (y compris celles relancées par le catch interne)
            console.error("An error occurred during optimizeSchedule execution:", error);
            // Vous pouvez enregistrer l'erreur en base de données ou faire autre chose si nécessaire
            return null; // Indique que la fonction a terminé (avec une erreur gérée)
        }
    }
);

// --- La fonction sendTaskNotifications (si vous la décommentez, assurez-vous que les imports sont corrects) ---
// const { schedule } = require("firebase-functions/pubsub"); // Cet import est pour les fonctions V1

// exports.sendTaskNotifications = schedule("every 1 minutes")
//     .onRun(async (context) => {
//         const now = new Date();
//         const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000);

//         // Ces requêtes doivent être adaptées à la structure de vos documents dans Firestore.
//         // Actuellement, elles s'attendent à ce que chaque document ait un champ 'startTime' et 'notified'.
//         // Or, votre emploi du temps est imbriqué par jour.
//         // Pour les notifications FCM déclenchées par une fonction Cloud, il faudrait une structure de données
//         // qui permette de requêter facilement les tâches à venir.
//         const userTasksSnapshot = await firestore
//             .collection("user_timetables")
//             .where("startTime", ">=", now.toISOString())
//             .where("startTime", "<=", fiveMinutesFromNow.toISOString())
//             .where("notified", "==", false)
//             .get();

//         const optimizedTasksSnapshot = await firestore
//             .collection("optimized_schedules")
//             .where("startTime", ">=", now.toISOString())
//             .where("startTime", "<=", fiveMinutesFromNow.toISOString())
//             .where("notified", "==", false)
//             .get();

//         const promises = [];
//         userTasksSnapshot.forEach((doc) =>
//             promises.push(sendNotification(doc.data(), doc.ref, doc.data().userId || "defaultUser"))
//         );
//         optimizedTasksSnapshot.forEach((doc) =>
//             promises.push(sendNotification(doc.data(), doc.ref, doc.data().userId || "defaultUser"))
//         );

//         await Promise.all(promises);
//         return null;
//     });

// async function sendNotification(task, docRef, userId) {
//     const userDoc = await firestore.collection("users").doc(userId).get();
//     const fcmToken = userDoc.data()?.fcmToken;

//     if (fcmToken) {
//         const message = {
//             notification: {
//                 title: `Rappel : ${task.title || "Tâche"}`,
//                 body: `Débute à ${new Date(task.startTime).toLocaleTimeString()}`,
//             },
//             token: fcmToken,
//         };

//         try {
//             await admin.messaging().send(message);
//             await firestore.collection("notifications").add({
//                 userId: userId,
//                 title: message.notification.title,
//                 body: message.notification.body,
//                 createdAt: admin.firestore.FieldValue.serverTimestamp(),
//             });
//             await docRef.update({ notified: true });
//         } catch (error) {
//             console.error("Error sending notification:", error);
//         }
//     }
// }
