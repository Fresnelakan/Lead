import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class OptimizedSchedulePage extends StatefulWidget {
  const OptimizedSchedulePage({super.key});

  @override
  State<OptimizedSchedulePage> createState() => _OptimizedSchedulePageState();
}

class _OptimizedSchedulePageState extends State<OptimizedSchedulePage> {
  User? _user;
  int _reminderMinutes = 5; // Délai de rappel par défaut
  bool _notificationsEnabled = false;
  bool _isSchedulingNotifications = false;
  bool _hasScheduled = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Vérifie si les notifications sont activées (placeholder)
  Future<void> _checkNotificationStatus() async {
    try {
      // Remplacement de notificationService par un placeholder
      // Suppose que les notifications sont désactivées par défaut
      bool enabled = false; // TODO: Implémenter la vérification des permissions
      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des notifications : $e');
    }
  }

  /// Convertit un nom de jour en numéro de jour de la semaine
  int? _getDayOfWeek(String dayName) {
    const dayMap = {
      'lundi': DateTime.monday,
      'mardi': DateTime.tuesday,
      'mercredi': DateTime.wednesday,
      'jeudi': DateTime.thursday,
      'vendredi': DateTime.friday,
      'samedi': DateTime.saturday,
      'dimanche': DateTime.sunday,
    };
    return dayMap[dayName.toLowerCase()];
  }

  /// Génère un ID unique pour les notifications
  int _generateNotificationId(String day, Map<String, dynamic> task) {
    final uniqueString = '${day}_${task['activity'] ?? ''}_${task['startTime'] ?? ''}_${task['endTime'] ?? ''}';
    final bytes = utf8.encode(uniqueString);
    final digest = sha1.convert(bytes);
    return digest.bytes.sublist(0, 4).fold(0, (prev, curr) => (prev << 8) + curr).abs() % 2147483647;
  }

  /// Planifie les notifications pour l'emploi du temps optimisé
  Future<void> _scheduleOptimizedScheduleNotifications(Map<String, dynamic> data) async {
    if (!mounted || _isSchedulingNotifications) return;

    setState(() {
      _isSchedulingNotifications = true;
    });

    try {
      if (!_notificationsEnabled) {
        // Remplacement de notificationService.requestNotificationPermissions()
        bool hasPermission = false; // TODO: Implémenter la demande de permissions
        if (!hasPermission && mounted) {
          _showPermissionDialog();
          return;
        }
        if (mounted) {
          setState(() {
            _notificationsEnabled = true;
          });
        }
      }

      // Remplacement de notificationService.cancelAllNotifications()
      print('🗑️ Placeholder : Annulation des notifications précédentes');

      final now = DateTime.now();
      int totalScheduled = 0;

      for (final entry in data.entries) {
        final jour = entry.key;
        final activites = entry.value;

        if (activites is! List || activites.isEmpty) {
          print('⚠️ Aucune activité pour : $jour');
          continue;
        }

        final targetDayOfWeek = _getDayOfWeek(jour);
        if (targetDayOfWeek == null) {
          print('⚠️ Jour invalide : $jour');
          continue;
        }

        DateTime nextOccurrence = now;
        while (nextOccurrence.weekday != targetDayOfWeek) {
          nextOccurrence = nextOccurrence.add(const Duration(days: 1));
        }

        for (var tache in activites) {
          try {
            final startTimeStr = tache['startTime'] as String? ?? '';
            if (startTimeStr.isEmpty) {
              print('⚠️ Heure de début manquante pour : ${tache['activity'] ?? 'Inconnu'}');
              continue;
            }

            final timeParts = startTimeStr.split(':');
            if (timeParts.length != 2) {
              print('⚠️ Format d\'heure invalide : $startTimeStr');
              continue;
            }

            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts[1]) ?? 0;

            DateTime scheduledDateTime = DateTime(
              nextOccurrence.year,
              nextOccurrence.month,
              nextOccurrence.day,
              hour,
              minute,
            );

            if (scheduledDateTime.isBefore(now)) {
              scheduledDateTime = scheduledDateTime.add(const Duration(days: 7));
            }

            final notificationId = _generateNotificationId(jour, tache);
            final activityName = tache['activity'] as String? ?? 'Activité';
            final note = tache['note'] as String? ?? '';

            String body = 'Votre activité "$activityName" commence à $startTimeStr';
            if (note.isNotEmpty) {
              body += '\n📝 Note : $note';
            }

            // Remplacement de notificationService.scheduleWeeklyRecurringNotification()
            print('✅ Placeholder : Notification planifiée pour "$activityName" le $jour à $startTimeStr '
                'avec ID $notificationId, titre "⏰ Rappel: $activityName", corps "$body", '
                'première occurrence $scheduledDateTime, rappel $_reminderMinutes min');

            totalScheduled++;
          } catch (e) {
            print('❌ Erreur lors de la planification pour ${tache['activity'] ?? 'Inconnu'} : $e');
          }
        }
      }

      if (mounted) {
        _showSchedulingSummary(totalScheduled);
      }
      // Remplacement de notificationService.listPendingNotifications()
      print('📋 Placeholder : Liste des notifications en attente');

    } catch (e) {
      print('❌ Erreur générale lors de la planification : $e');
      if (mounted) {
        _showErrorDialog('Erreur lors de la planification des notifications : $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSchedulingNotifications = false;
        });
      }
    }
  }

  /// Affiche une boîte de dialogue pour demander les permissions
  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔔 Permissions requises'),
        content: const Text(
          'L\'application a besoin de la permission pour afficher des notifications afin de vous rappeler vos activités.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Remplacement de notificationService.requestNotificationPermissions()
              bool hasPermission = false; // TODO: Implémenter la demande de permissions
              if (mounted && hasPermission) {
                setState(() {
                  _notificationsEnabled = true;
                });
              }
            },
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
  }

  /// Affiche un résumé du nombre de notifications planifiées
  void _showSchedulingSummary(int count) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $count activités programmées avec rappels $_reminderMinutes min avant'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Affiche une boîte de dialogue en cas d'erreur
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Construit le widget des paramètres de notification
  Widget _buildReminderSettings() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚙️ Paramètres de notification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Rappel : '),
                DropdownButton<int>(
                  value: _reminderMinutes,
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 minutes avant')),
                    DropdownMenuItem(value: 5, child: Text('5 minutes avant')),
                    DropdownMenuItem(value: 10, child: Text('10 minutes avant')),
                    DropdownMenuItem(value: 15, child: Text('15 minutes avant')),
                    DropdownMenuItem(value: 30, child: Text('30 minutes avant')),
                  ],
                  onChanged: (value) {
                    if (value != null && mounted) {
                      setState(() {
                        _reminderMinutes = value;
                        _hasScheduled = false;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                  color: _notificationsEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _notificationsEnabled ? 'Notifications activées' : 'Notifications désactivées',
                  style: TextStyle(
                    color: _notificationsEnabled ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('📅 Emploi du Temps Optimisé')),
        body: const Center(
          child: Text('🔐 Connectez-vous pour voir votre emploi du temps.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Emploi du Temps Optimisé'),
        actions: [
          if (_isSchedulingNotifications)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSchedulingNotifications
                ? null
                : () {
                    setState(() {
                      _hasScheduled = false;
                    });
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReminderSettings(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('optimized_schedules')
                  .doc(_user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('❌ Erreur : ${snapshot.error}'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text('📋 Aucun emploi du temps optimisé trouvé.'),
                  );
                }

                final Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null || data.isEmpty) {
                  return const Center(
                    child: Text('📋 Aucun emploi du temps optimisé trouvé.'),
                  );
                }

                if (!_isSchedulingNotifications && !_hasScheduled && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _scheduleOptimizedScheduleNotifications(data);
                      setState(() {
                        _hasScheduled = true;
                      });
                    }
                  });
                }

                final List<DataRow> rows = [];
                data.forEach((jour, activites) {
                  if (activites is List && activites.isNotEmpty) {
                    for (var tache in activites) {
                      final startTime = tache['startTime'] as String? ?? '';
                      final endTime = tache['endTime'] as String? ?? '';
                      final activity = tache['activity'] as String? ?? 'Activité';
                      final note = tache['note'] as String? ?? '';

                      rows.add(DataRow(
                        cells: [
                          DataCell(Text(
                            jour[0].toUpperCase() + jour.substring(1),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          )),
                          DataCell(Text(
                            '$startTime - $endTime',
                            style: const TextStyle(fontFamily: 'monospace'),
                          )),
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  activity,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                if (note.isNotEmpty)
                                  Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ));
                    }
                  }
                });

                return SingleChildScrollView(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                        columns: const <DataColumn>[
                          DataColumn(
                            label: Text('📅 Jour', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('⏰ Heure', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('📋 Activité', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                        rows: rows,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSchedulingNotifications
            ? null
            : () async {
                try {
                  // Remplacement de notificationService.showInstantNotification()
                  print('🧪 Placeholder : Notification de test affichée avec ID 999, '
                      'titre "🧪 Test de notification", corps "Ceci est un test pour vérifier que les notifications fonctionnent !"');
                } catch (e) {
                  print('❌ Erreur lors du test de notification : $e');
                  if (mounted) {
                    _showErrorDialog('Erreur lors du test de notification : $e');
                  }
                }
              },
        icon: const Icon(Icons.notification_important),
        label: const Text('Test'),
      ),
    );
  }
}