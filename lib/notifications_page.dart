import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('optimized_schedules')
            .where('userId', isEqualTo: user.uid)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.now())
            .orderBy('startTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erreur de chargement'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data!.docs;

          if (activities.isEmpty) {
            return const Center(child: Text('Aucune activité à venir'));
          }

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final data = activities[index].data() as Map<String, dynamic>;
              final activity = data['activity'] as String;
              final Timestamp startTimeStamp = data['startTime'] as Timestamp;
              final DateTime startTime = startTimeStamp.toDate();

              return ListTile(
                title: Text(activity),
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