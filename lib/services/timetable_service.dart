import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lead/services/notification_service.dart';

class TimetableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> scheduleNotificationsForTimetable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

   

    // Récupérer les activités à venir
    final QuerySnapshot snapshot = await _firestore
        .collection('optimized_schedules')
        .where('userId', isEqualTo: user.uid)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.now())
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final activity = data['activity'] as String;
      final Timestamp startTimeStamp = data['startTime'] as Timestamp;
      final DateTime startTime = startTimeStamp.toDate();

      await NotificationService.scheduleNotification(
        id: doc.id.hashCode,
        title: 'Activité à venir : $activity',
        body: 'Votre activité "$activity" commence à ${startTime.hour}:${startTime.minute.toString().padStart(2, '0')}.',
        scheduledTime: startTime,
      );
    }
  }
}