// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const functions = require("firebase-functions");

// The Firebase Admin SDK to access Firestore.
const admin = require("firebase-admin");
admin.initializeApp();

// Importez la bibliothèque pour l'API Gemini
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { onDocumentWritten } = require("firebase-functions/firestore");

// --- Configuration sécurisée de la clé API Gemini ---
const apiKey = functions.config().gemini.api_key;

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
        // region: "europe-west1", // Décommentez si votre fonction est déployée dans une région spécifique
    },
    async (event) => {
        const userId = event.params.userId;
        const timetableData = event.data?.after?.data();

        // Si le document est supprimé ou n'a pas de données après l'écriture, ne faites rien.
        if (!timetableData) {
            console.log("No data associated with the event or document deleted.");
            return null;
        }

        console.log(`Optimizing schedule for user: ${userId}`);
        console.log("Received timetable data:", JSON.stringify(timetableData));

        try {
            const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"});

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
            
            console.log("Prompt sent to Gemini:", prompt);

            const result = await model.generateContent(prompt);
            const response = await result.response;

            let optimizedScheduleJsonString = response.text();

            console.log("Raw response text from Gemini:", response.text());

            // Nettoyer la réponse: Supprimer les marqueurs de bloc de code Markdown si présents
            const jsonStartMarker = "```json";
            const codeBlockEndMarker = "```";

            const jsonStartIndex = optimizedScheduleJsonString.indexOf(jsonStartMarker);
            const jsonEndIndex = optimizedScheduleJsonString.lastIndexOf(codeBlockEndMarker);

            if (jsonStartIndex !== -1 && jsonEndIndex !== -1 && jsonEndIndex > jsonStartIndex) {
                optimizedScheduleJsonString = optimizedScheduleJsonString.substring(jsonStartIndex + jsonStartMarker.length, jsonEndIndex).trim();
            } else if (optimizedScheduleJsonString.startsWith(codeBlockEndMarker) && optimizedScheduleJsonString.endsWith(codeBlockEndMarker)) {
                optimizedScheduleJsonString = optimizedScheduleJsonString.substring(codeBlockEndMarker.length, optimizedScheduleJsonString.length - codeBlockEndMarker.length).trim();
            }
            // Ajoutez d'autres cas si Gemini renvoie d'autres formats inattendus (ex: `json\n{...}\n`)

            console.log("Cleaned JSON string for parsing:", optimizedScheduleJsonString);

            let optimizedScheduleData;
            try {
                optimizedScheduleData = JSON.parse(optimizedScheduleJsonString);
            } catch (parseError) {
                console.error("Failed to parse JSON after cleaning:", parseError);
                console.error("String that caused parsing error:", optimizedScheduleJsonString);
                throw new Error("Failed to parse Gemini response as valid JSON after cleaning.");
            }

            console.log("Optimized schedule data received from Gemini (parsed):", optimizedScheduleData);

            const optimizedScheduleRef = firestore.collection("optimized_schedules").doc(userId);
            await optimizedScheduleRef.set(optimizedScheduleData);

            console.log(`Optimized schedule saved to Firestore for user: ${userId}`);

            // --- NOUVEAU: ENVOI DE LA NOTIFICATION FCM ---
            const userDoc = await firestore.collection("users").doc(userId).get();
            const fcmToken = userDoc.data()?.fcmToken;

            if (fcmToken) {
                const message = {
                    notification: {
                        title: 'Emploi du temps optimisé prêt ! 🎉',
                        body: 'Votre nouveau planning avec les suggestions d\'activités est disponible. Jetez-y un œil !',
                    },
                    data: {
                        // Données personnalisées pour gérer le clic sur la notification
                        // Par exemple, naviguer vers la page de l'emploi du temps optimisé
                        page: 'optimized_schedule', // Vous devrez implémenter la navigation côté Flutter/Web
                        userId: userId,
                    },
                    token: fcmToken,
                };

                try {
                    const fcmResponse = await admin.messaging().send(message);
                    console.log('Notification FCM envoyée avec succès:', fcmResponse);
                } catch (fcmError) {
                    console.error('Erreur lors de l\'envoi de la notification FCM:', fcmError);
                }
            } else {
                console.log('Aucun token FCM trouvé pour l\'utilisateur:', userId, '. Impossible d\'envoyer la notification.');
            }
            // --- FIN NOUVEAU ---

            return null;
        } catch (error) {
            console.error("An error occurred during optimizeSchedule execution:", error);
            return null;
        }
    }
);

// --- Fonctions de rappel basées sur le temps (Commentées - nécessitent une refonte des requêtes) ---
// La fonction `sendTaskNotifications` commentée ici nécessite une structure de données Firestore
// qui permet de requêter facilement les tâches individuelles avec des timestamps.
// Votre structure actuelle imbrique les activités par jour, ce qui rend les requêtes temporelles directes difficiles.
// Pour des rappels précis avant chaque activité, vous devrez soit:
// 1. Dénormaliser vos données (ex: avoir une collection 'all_activities' avec des docs pour chaque tâche et leur startTime).
// 2. Parcourir de manière plus complexe le document 'optimized_schedules' par jour dans cette Cloud Function planifiée,
//    ce qui peut être coûteux en lectures Firestore.

/*
const { schedule } = require("firebase-functions/pubsub");

exports.sendTaskNotifications = schedule("every 1 minutes")
    .onRun(async (context) => {
        const now = new Date();
        const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000);

        // Cette logique doit être adaptée pour parcourir les activités dans optimized_schedules
        // qui sont structurées par jour (Lundi, Mardi, etc.) avec des heures de début/fin
        // et non directement dans des documents individuels avec 'startTime'.

        // Exemple conceptuel de ce qu'il faudrait faire:
        const allOptimizedSchedules = await firestore.collection("optimized_schedules").get();
        const notificationPromises = [];

        allOptimizedSchedules.forEach(doc => {
            const userId = doc.id; // L'ID du document est l'UID de l'utilisateur
            const scheduleData = doc.data();

            for (const day in scheduleData) {
                if (Array.isArray(scheduleData[day])) {
                    scheduleData[day].forEach(activity => {
                        // Assurez-vous que chaque activité a startTime au format attendu (ex: "HH:MM")
                        // Vous devrez convertir ces chaînes en objets Date pour la comparaison.
                        // Cela rend la logique complexe car la date exacte n'est pas dans le planning.
                        // Pour un rappel "dans 5 minutes", il faudrait connaître la date complète de l'activité.

                        // Si votre 'startTime' dans Firestore est un Timestamp, c'est plus simple.
                        // Si c'est une chaîne "HH:MM", il faudra reconstituer la Date du jour actuel.
                        const activityStartTimeStr = activity.startTime; // Ex: "09:00"
                        const activityActivityName = activity.activity; // Ex: "Révision Maths"

                        // Exemple simplifié pour une activité qui commence dans les 5 prochaines minutes
                        // Ceci est un PSEUDO-CODE car l'implémentation exacte dépend du format de vos dates
                        // et si vous voulez des rappels journaliers ou une seule fois.
                        // Si 'startTime' est un Timestamp Firestore, c'est idéal:
                        // const activityStartTime = activity.startTime.toDate(); // Si c'est un Timestamp

                        // Logique complexe si 'startTime' est juste "HH:MM" et 'day' est "Lundi"
                        // Il faudrait déterminer le prochain Lundi à cette heure.
                        // Ceci est au-delà du scope d'une simple adaptation ici sans plus de détails.

                        // Si vous aviez une collection 'user_activities' avec chaque tâche comme un document
                        // { userId: "...", activity: "...", startTime: Timestamp, notified: false }
                        // Alors la requête initiale avec .where("startTime", ">=", now) fonctionnerait.

                        // Pour l'exemple, supposons que vous ayez une structure où vous pouvez identifier
                        // les tâches qui doivent être notifiées.
                        // Si on veut notifier quand une activité est dans la tranche [now, fiveMinutesFromNow]
                        // et qu'elle n'a pas encore été notifiée (vous devrez ajouter un champ 'notified'
                        // ou 'lastNotifiedAt' à l'activité elle-même dans le planning optimisé).

                        // Ceci est une ébauche de la logique pour envoyer la notification.
                        // Il vous faudra l'adapter à votre logique de détection des activités à notifier.
                        // notificationPromises.push(sendNotification(activity, firestore.collection('optimized_schedules').doc(userId), userId));
                    });
                }
            }
        });

        await Promise.all(notificationPromises);
        return null;
    });

async function sendNotification(task, docRef, userId) {
    const userDoc = await firestore.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
        const message = {
            notification: {
                title: `Rappel : ${task.activity || task.title || "Tâche"}`,
                body: `Débute à ${task.startTime ? task.startTime : "bientôt"}`,
            },
            data: {
                // Vous pouvez ajouter l'ID de l'activité pour un lien profond
                activityId: task.id || 'unknown',
                page: 'optimized_schedule', // Pour diriger l'utilisateur
            },
            token: fcmToken,
        };

        try {
            await admin.messaging().send(message);
            console.log(`Notification envoyée pour l'utilisateur ${userId}: ${message.notification.title}`);
            // Optionnel: Ajouter un enregistrement de la notification envoyée
            await firestore.collection("sent_notifications").add({
                userId: userId,
                title: message.notification.title,
                body: message.notification.body,
                activity: task.activity,
                startTime: task.startTime,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // NOTE: Pour marquer l'activité comme 'notified', vous devriez
            // mettre à jour la sous-entrée spécifique dans le document optimized_schedules,
            // ce qui est plus complexe qu'une simple mise à jour de champ de document.
        } catch (error) {
            console.error(`Erreur lors de l'envoi de notification pour l'utilisateur ${userId}:`, error);
        }
    }
}
*/
