import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
  }

  // Fonction utilitaire pour extraire et aplatir les activités du planning
  List<Map<String, dynamic>> _extractAndFilterActivities(
      Map<String, dynamic> scheduleData) {
    List<Map<String, dynamic>> upcomingActivities = [];
    final now = DateTime.now();

    scheduleData.forEach((day, activities) {
      if (activities is List) {
        for (var activity in activities) {
          if (activity['activity'] != null &&
              activity['startTime'] != null &&
              activity['endTime'] != null) {
            try {
              // Assurez-vous que le champ 'priority' ou 'importance' existe dans vos données Firestore
              // Si ce champ n'existe pas, toutes les activités seront considérées non-pertinentes pour la notification ici.
              // Pour la démo, si le champ n'est pas encore là, vous pouvez le mocker ou assumer une valeur par défaut.
              // Exemple: Si vous n'avez pas de 'priority', ajoutez || true pour inclure toutes les activités pour la démo.
              final String? priority = activity['priority'] as String?; // Supposons un champ 'priority'

              // NE PLANIFIER QUE SI L'ACTIVITÉ EST "utile" OU "très utile"
              // Correct (pour le JSON IA)
              if (priority == null || (priority != 'high' && priority != 'essential')) {
                continue;
              }

              final String timeString = activity['startTime']; // Ex: "09:00"
              final List<String> timeParts = timeString.split(':');
              final int hour = int.parse(timeParts[0]);
              final int minute = int.parse(timeParts[1]);

              int dayIndex = _getDayIndex(day.toLowerCase());
              DateTime activityDateTime = _getNextWeekdayDateTime(dayIndex, hour, minute);

              // Ne pas inclure les activités passées
              if (activityDateTime.isBefore(now)) {
                continue;
              }

              upcomingActivities.add({
                'activity': activity['activity'],
                'startTime': activityDateTime, // Maintenant un objet DateTime
                'endTime': activity['endTime'],
                'day': day,
                'priority': priority, // Ajoute la propriété d'utilité pour l'affichage si besoin
              });
            } catch (e) {
              print('Erreur de parsing de l\'activité: $activity, Erreur: $e');
            }
          }
        }
      }
    });

    upcomingActivities.sort((a, b) => (a['startTime'] as DateTime)
        .compareTo(b['startTime'] as DateTime));

    return upcomingActivities;
  }

  int _getDayIndex(String day) {
    switch (day.toLowerCase()) {
      case 'lundi':
        return 1;
      case 'mardi':
        return 2;
      case 'mercredi':
        return 3;
      case 'jeudi':
        return 4;
      case 'vendredi':
        return 5;
      case 'samedi':
        return 6;
      case 'dimanche':
        return 7;
      default:
        return 1; // Par défaut Lundi
    }
  }

  DateTime _getNextWeekdayDateTime(int targetWeekday, int hour, int minute) {
    DateTime now = DateTime.now();
    int daysToAdd = targetWeekday - now.weekday;
    if (daysToAdd < 0) { // Si le jour cible est déjà passé cette semaine
      daysToAdd += 7;
    } else if (daysToAdd == 0 && (now.hour > hour || (now.hour == hour && now.minute >= minute))) {
      // Si c'est le même jour mais l'heure est déjà passée ou actuelle
      daysToAdd += 7;
    }

    DateTime nextActivityDate = DateTime(
      now.year,
      now.month,
      now.day + daysToAdd,
      hour,
      minute,
    );
    return nextActivityDate;
  }

  // Fonction pour planifier une demande de notification push en écrivant dans Firestore
  Future<void> _schedulePushNotificationRequest(Map<String, dynamic> activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Le filtre est déjà fait dans _extractAndFilterActivities, mais on peut vérifier à nouveau
    final String? priority = activity['priority'] as String?;
    if (priority == null || (priority != 'utile' && priority != 'très utile')) {
      print('Activité ${activity['activity']} non "utile" ou "très utile". Notification non planifiée.');
      return; // Ne planifie pas si l'utilité n'est pas "utile" ou "très utile"
    }

    final notificationTime = (activity['startTime'] as DateTime).subtract(const Duration(minutes: 3));

    if (notificationTime.isBefore(DateTime.now())) {
      print('Notification pour ${activity['activity']} déjà passée. Non planifiée.');
      return;
    }

    // Un ID unique pour éviter les doublons dans Firestore
    final notificationRequestId = '${user.uid}-${activity['activity']}-${notificationTime.toIso8601String()}';

    // Vérifier si cette notification a déjà été planifiée
    final existingNotificationDoc = await FirebaseFirestore.instance
        .collection('notification_requests') // Utiliser une collection dédiée aux requêtes
        .doc(notificationRequestId)
        .get();

    if (existingNotificationDoc.exists) {
      print('Demande de notification pour ${activity['activity']} existe déjà. Pas de doublon.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('notification_requests') // Collection pour stocker les requêtes de notifications
        .doc(notificationRequestId)
        .set({
          'userId': user.uid,
          'activityName': activity['activity'],
          'scheduledTime': Timestamp.fromDate(notificationTime),
          'title': 'Rappel : ${activity['activity']}',
          'body': 'Votre activité "${activity['activity']}" commence à ${activity['startTime'].toLocal().toString().substring(11, 16)}.',
          'originalActivityStartTime': Timestamp.fromDate(activity['startTime']),
          'status': 'pending', // 'pending', 'sent', 'failed'
          'type': priority, // Garder le type d'utilité pour le contexte
        });
    print('Demande de notification pour ${activity['activity']} planifiée dans Firestore (utilité: $priority).');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.blue[50],
          elevation: 0,
          foregroundColor: Colors.black,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        body: const Center(child: Text('Veuillez vous connecter pour voir vos notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications pertinentes'), // Titre plus spécifique
        backgroundColor: Colors.blue[50],
        elevation: 0,
        foregroundColor: Colors.black,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('optimized_schedules')
            .doc(user.uid) // Assurez-vous que l'emploi du temps optimisé est stocké par UID de l'utilisateur
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement des notifications: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucun emploi du temps optimisé trouvé ou aucune activité pertinente à notifier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final Map<String, dynamic>? rawScheduleData =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (rawScheduleData == null || rawScheduleData.isEmpty) {
            return const Center(child: Text('Aucune activité à notifier.'));
          }

          // Extrait et filtre les activités basées sur "utile" ou "très utile"
          final List<Map<String, dynamic>> activitiesToNotify =
              _extractAndFilterActivities(rawScheduleData);

          // Planifier les demandes de notifications push pour CHAQUE activité filtrée
          // Ceci se déclenchera à chaque fois que le StreamBuilder reçoit une mise à jour.
          // C'est pourquoi la logique de dédoublonnage dans _schedulePushNotificationRequest est importante.
          for (var activity in activitiesToNotify) {
            _schedulePushNotificationRequest(activity);
          }

          if (activitiesToNotify.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucune notification pertinente pour le moment. '
                  'Les notifications s\'affichent uniquement pour les activités jugées "utile" ou "très utile".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: activitiesToNotify.length,
            itemBuilder: (context, index) {
              final activity = activitiesToNotify[index];
              final DateTime startTime = activity['startTime'] as DateTime;
              final String priority = activity['priority'] as String? ?? 'Non spécifié';

              // Calcul du temps restant avant la notification (3 min avant le début)
              final DateTime notificationTime = startTime.subtract(const Duration(minutes: 3));
              final Duration timeLeft = notificationTime.difference(DateTime.now());

              String timeLeftText;
              if (timeLeft.isNegative) {
                timeLeftText = "Notification déjà envoyée";
              } else if (timeLeft.inHours > 0) {
                timeLeftText = "Notification dans ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}min";
              } else {
                timeLeftText = "Notification dans ${timeLeft.inMinutes}min";
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    priority == 'high' ? Icons.star : Icons.check_circle,
                    color: priority == 'high' ? Colors.amber : Colors.blue,
                  ),
                  title: Text(
                    activity['activity'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Début : ${startTime.toLocal().toString().substring(0, 16)}',
                      ),
                      Text(
                        'Priorité: ${priority == 'high' ? 'Très utile' : priority == 'essential' ? 'Essentielle' : priority}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeLeftText,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.notifications_active, color: Colors.green),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}