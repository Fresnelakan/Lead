import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Fonction pour extraire et filtrer les activités
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
              final String timeString = activity['startTime']; // Ex: "09:00"
              final List<String> timeParts = timeString.split(':');
              final int hour = int.parse(timeParts[0]);
              final int minute = int.parse(timeParts[1]);

              // Associer le jour à une date future si nécessaire
              int dayIndex = _getDayIndex(day.toLowerCase());
              DateTime activityDateTime = DateTime(
                now.year,
                now.month,
                now.day + (dayIndex >= now.weekday ? dayIndex - now.weekday : 7 - now.weekday + dayIndex),
                hour,
                minute,
              );

              // Ignorer les activités passées
              if (activityDateTime.isBefore(now)) {
                continue;
              }

              upcomingActivities.add({
                'activity': activity['activity'],
                'startTime': activityDateTime,
                'endTime': activity['endTime'],
                'day': day,
              });
            } catch (e) {
              print('Erreur de parsing de l\'activité: $activity, Erreur: $e');
            }
          }
        }
      }
    });

    // Trier les activités par heure de début
    upcomingActivities.sort((a, b) => (a['startTime'] as DateTime)
        .compareTo(b['startTime'] as DateTime));

    return upcomingActivities;
  }

  // Convertir le nom du jour en index (lundi=1, ..., dimanche=7)
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
        return 1; // Par défaut, lundi
    }
  }

  // Fonction pour planifier une notification push via une Cloud Function
  Future<void> _schedulePushNotification(Map<String, dynamic> activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notificationTime = (activity['startTime'] as DateTime).subtract(Duration(minutes: 3));
    if (notificationTime.isBefore(DateTime.now())) return;

    // Stocker les détails de la notification dans Firestore
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc()
        .set({
      'userId': user.uid,
      'title': 'Rappel : ${activity['activity']}',
      'body': 'Votre activité "${activity['activity']}" commence à ${activity['startTime'].toLocal().toString().substring(11, 16)}.',
      'scheduledTime': Timestamp.fromDate(notificationTime),
      'activityId': activity['startTime'].hashCode.toString(),
      'delivered': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Veuillez vous connecter')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('optimized_schedules')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
            return const Center(child: Text('Aucun emploi du temps optimisé trouvé.'));
          }

          final Map<String, dynamic>? rawScheduleData =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (rawScheduleData == null || rawScheduleData.isEmpty) {
            return const Center(child: Text('Aucun emploi du temps optimisé trouvé.'));
          }

          // Extraire et filtrer les activités
          final List<Map<String, dynamic>> activities =
              _extractAndFilterActivities(rawScheduleData);

          // Planifier les notifications push pour chaque activité
          for (var activity in activities) {
            _schedulePushNotification(activity);
          }

          if (activities.isEmpty) {
            return const Center(child: Text('Aucune activité à venir'));
          }

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final DateTime startTime = activity['startTime'] as DateTime;

              return ListTile(
                title: Text(activity['activity']),
                subtitle: Text('Début : ${startTime.toLocal().toString().substring(0, 16)}'),
                trailing: const Icon(Icons.notifications_active),
              );
            },
          );
        },
      ),
    );
  }
}