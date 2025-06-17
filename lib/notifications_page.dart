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
              final String timeString = activity['startTime']; // Ex: "09:00"
              final List<String> timeParts = timeString.split(':');
              final int hour = int.parse(timeParts[0]);
              final int minute = int.parse(timeParts[1]);

              int dayIndex = _getDayIndex(day.toLowerCase());
              DateTime activityDateTime = _getNextWeekdayDateTime(dayIndex, hour, minute);

              if (activityDateTime.isBefore(now)) {
                continue;
              }

              upcomingActivities.add({
                'activity': activity['activity'],
                'startTime': activityDateTime, // Maintenant un objet DateTime
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
        return 1;
    }
  }

  DateTime _getNextWeekdayDateTime(int targetWeekday, int hour, int minute) {
    DateTime now = DateTime.now();
    int daysToAdd = targetWeekday - now.weekday;
    if (daysToAdd <= 0) {
      daysToAdd += 7;
    }

    DateTime nextActivityDate = DateTime(
      now.year,
      now.month,
      now.day + daysToAdd,
      hour,
      minute,
    );

    if (nextActivityDate.isBefore(now) && nextActivityDate.weekday == now.weekday) {
      nextActivityDate = nextActivityDate.add(const Duration(days: 7));
    }

    return nextActivityDate;
  }

  // Fonction pour planifier une demande de notification push en écrivant dans Firestore
  Future<void> _schedulePushNotificationRequest(Map<String, dynamic> activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notificationTime = (activity['startTime'] as DateTime).subtract(const Duration(minutes: 3));

    if (notificationTime.isBefore(DateTime.now())) {
      print('Notification pour ${activity['activity']} déjà passée. Non planifiée.');
      return;
    }

    final notificationRequestId = '${user.uid}-${activity['startTime'].millisecondsSinceEpoch}-${activity['activity'].hashCode}';

    final existingNotificationDocs = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('activityId', isEqualTo: activity['startTime'].hashCode.toString())
        .where('scheduledTime', isEqualTo: Timestamp.fromDate(notificationTime))
        .get();

    if (existingNotificationDocs.docs.isNotEmpty) {
      print('Demande de notification pour ${activity['activity']} existe déjà. Pas de doublon.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationRequestId)
        .set({
      'userId': user.uid,
      'title': 'Rappel : ${activity['activity']}',
      'body': 'Votre activité "${activity['activity']}" commence à ${activity['startTime'].toLocal().toString().substring(11, 16)}.',
      'scheduledTime': Timestamp.fromDate(notificationTime),
      'activityId': activity['startTime'].hashCode.toString(),
      'delivered': false,
    });
    print('Demande de notification pour ${activity['activity']} planifiée dans Firestore.');
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
          // Bouton hamburger pour ouvrir le Drawer
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        body: const Center(child: Text('Veuillez vous connecter')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue[50],
        elevation: 0,
        foregroundColor: Colors.black,
        // Bouton hamburger pour ouvrir le Drawer
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
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
            return const Center(child: Text('Aucune activité à venir')); // Texte mis à jour pour plus de clarté
          }

          final Map<String, dynamic>? rawScheduleData =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (rawScheduleData == null || rawScheduleData.isEmpty) {
            return const Center(child: Text('Aucune activité à venir'));
          }

          final List<Map<String, dynamic>> activities =
              _extractAndFilterActivities(rawScheduleData);

          // Planifier les demandes de notifications push pour chaque activité à venir
          for (var activity in activities) {
            _schedulePushNotificationRequest(activity);
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
