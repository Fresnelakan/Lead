import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lead/services/notification_service.dart'; // Assurez-vous que le chemin est correct
import 'package:timezone/timezone.dart' as tz; // Import pour les types timezone

class OptimizedSchedulePage extends StatefulWidget {
  const OptimizedSchedulePage({super.key});

  @override
  State<OptimizedSchedulePage> createState() => _OptimizedSchedulePageState();
}

class _OptimizedSchedulePageState extends State<OptimizedSchedulePage> {
  User? _user;
  // Flag pour s'assurer que les notifications ne sont planifiées qu'une seule fois par mise à jour de données
  bool _notificationsScheduled = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  // Fonction pour convertir le nom du jour en jour de la semaine de DateTime
  int? _getDayOfWeek(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'lundi':
        return DateTime.monday;
      case 'mardi':
        return DateTime.tuesday;
      case 'mercredi':
        return DateTime.wednesday;
      case 'jeudi':
        return DateTime.thursday;
      case 'vendredi':
        return DateTime.friday;
      case 'samedi':
        return DateTime.saturday;
      case 'dimanche':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  // Fonction pour planifier les notifications basées sur l'emploi du temps optimisé
  void _scheduleOptimizedScheduleNotifications(Map<String, dynamic> data) async {
    // Éviter de planifier plusieurs fois si les données n'ont pas changé
    if (_notificationsScheduled) {
      return;
    }

    // Annuler toutes les anciennes notifications pour éviter les doublons
    await NotificationService.cancelAllNotifications();
    print('Anciennes notifications annulées.');

    final now = DateTime.now();
    int notificationIdCounter = 0; // Compteur pour des IDs uniques

    data.forEach((jour, activites) {
      if (activites is List) {
        final int? targetDayOfWeek = _getDayOfWeek(jour);
        if (targetDayOfWeek == null) {
          print('Jour invalide trouvé: $jour');
          return;
        }

        // Trouver la prochaine occurrence de ce jour de la semaine
        // Si aujourd'hui est le jour, nous planifions pour aujourd'hui si l'heure est dans le futur
        // Sinon, nous planifions pour la semaine prochaine
        DateTime nextOccurrenceOfDay = now;
        while (nextOccurrenceOfDay.weekday != targetDayOfWeek) {
          nextOccurrenceOfDay = nextOccurrenceOfDay.add(const Duration(days: 1));
        }

        // Ajuster si le jour cible est passé pour cette semaine (et prendre la semaine suivante)
        if (nextOccurrenceOfDay.isBefore(now) && nextOccurrenceOfDay.weekday == now.weekday) {
          // Si le jour est aujourd'hui mais l'heure est passée, nous prenons la semaine prochaine
          // Cette logique sera affinée lors de la combinaison avec l'heure
        }


        for (var tache in activites) {
          try {
            final String startTimeStr = tache['startTime']; // Ex: "10:00"
            final String activityTitle = tache['activity'];
            final String? activityDescription = tache['description']; // Si vous avez une description

            final List<String> timeParts = startTimeStr.split(':');
            final int hour = int.parse(timeParts[0]);
            final int minute = int.parse(timeParts[1]);

            // Construire la date et l'heure complètes pour la notification
            // Vérifier si l'événement est pour la semaine en cours ou la semaine suivante
            DateTime scheduledDateTime = tz.TZDateTime(
              tz.local,
              nextOccurrenceOfDay.year,
              nextOccurrenceOfDay.month,
              nextOccurrenceOfDay.day,
              hour,
              minute,
            );

            // Si l'heure de début de l'activité est déjà passée aujourd'hui, planifier pour la semaine prochaine
            if (scheduledDateTime.isBefore(now)) {
                // Si c'est le même jour mais l'heure est passée, on décale d'une semaine
                scheduledDateTime = scheduledDateTime.add(const Duration(days: 7));
            }


            // Planifier la notification 15 minutes avant le début de l'événement
            final DateTime reminderTime = scheduledDateTime.subtract(const Duration(minutes: 15));

            // Assurez-vous que l'heure de rappel est dans le futur
            if (reminderTime.isAfter(now)) {
              notificationIdCounter++; // Incrémente le compteur pour un ID unique
              NotificationService.scheduleNotification(
                id: notificationIdCounter, // ID unique pour chaque notification
                title: 'Rappel: $activityTitle',
                body: 'Votre activité "${activityTitle}" commence dans 15 minutes. ${activityDescription ?? ''}',
                scheduledDate: reminderTime,
                payload: '{"day": "$jour", "activity": "$activityTitle", "time": "$startTimeStr"}', // Exemple de payload JSON
              );
              print('Notification planifiée pour ${activityTitle} le $jour à ${reminderTime}');
            } else {
              print('L\'heure de rappel pour ${activityTitle} le $jour est passée ou est trop proche pour être planifiée.');
            }
          } catch (e) {
            print('Erreur lors de la planification d\'une notification: $e');
            print('Données de l\'activité en cause: $tache');
          }
        }
      }
    });

    // Marquer que les notifications ont été planifiées pour cette mise à jour de données
    _notificationsScheduled = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emploi du Temps Optimisé')),
        body: const Center(
          child: Text(
            'Veuillez vous connecter pour voir votre emploi du temps optimisé.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Emploi du Temps Optimisé')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('optimized_schedules')
            .doc(_user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            _notificationsScheduled = false; // Réinitialiser si en attente de nouvelles données
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            _notificationsScheduled = false;
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            _notificationsScheduled = false;
            return const Center(
              child: Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
              ),
            );
          }

          final Map<String, dynamic>? data =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null || data.isEmpty) {
            _notificationsScheduled = false;
            return const Center(
              child: Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
              ),
            );
          }

          // Planifier les notifications après que les données soient disponibles
          // Utilisez addPostFrameCallback pour s'assurer que le contexte est valide après la construction du widget
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scheduleOptimizedScheduleNotifications(data);
          });


          // Construction des lignes du tableau (logique existante)
          final List<DataRow> rows = [];
          data.forEach((jour, activites) {
            if (activites is List) {
              for (var tache in activites) {
                rows.add(
                  DataRow(
                    cells: [
                      DataCell(Text(jour[0].toUpperCase() + jour.substring(1))),
                      DataCell(
                        Text('${tache['startTime']} - ${tache['endTime']}'),
                      ),
                      DataCell(Text('${tache['activity']}')),
                    ],
                  ),
                );
              }
            }
          });

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Jour')),
                  DataColumn(label: Text('Heure')),
                  DataColumn(label: Text('Activité')),
                ],
                rows: rows,
              ),
            ),
          );
        },
      ),
    );
  }
}