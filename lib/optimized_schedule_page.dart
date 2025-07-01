import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lead/services/notification_service.dart'; // Assurez-vous que le chemin est correct
import 'main.dart'; // Pour accéder à l'instance globale de flutterLocalNotificationsPlugin
import 'home_page.dart'; // Importez home_page.dart pour accéder à TimetableSetupScreen si elle n'est pas dans le même fichier
// Il est crucial que ActivityDisplay soit accessible. Si home_page.dart est le seul fichier,
// ActivityDisplay devrait être défini dans ce même fichier ou importé d'un fichier utilitaire.

class OptimizedSchedulePage extends StatefulWidget {
  const OptimizedSchedulePage({super.key});

  @override
  State<OptimizedSchedulePage> createState() => _OptimizedSchedulePageState();
}

class _OptimizedSchedulePageState extends State<OptimizedSchedulePage> {
  User? _user;
  Map<String, dynamic>? _optimizedTimetableData; // Données de l'emploi du temps optimisé
  bool _isLoading = true; // État de chargement

  final NotificationService _notificationService = NotificationService(flutterLocalNotificationsPlugin);


  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _loadOptimizedTimetable(); // Charger l'emploi du temps optimisé au démarrage
  }

  // Charge l'emploi du temps optimisé depuis Firestore
  Future<void> _loadOptimizedTimetable() async {
    if (_user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('optimized_schedules')
          .doc(_user!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _optimizedTimetableData = doc.data();
          _isLoading = false;
        });
        print('Emploi du temps optimisé chargé avec succès.');
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Aucun emploi du temps optimisé trouvé pour l\'utilisateur ${_user!.uid}.');
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'emploi du temps optimisé: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  // --- Fonctions de rendu et de logique copiées de _TimetableViewScreenState pour la cohérence ---

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int hour = 7; hour <= 22; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      slots.add('${hour.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  Map<String, ActivityDisplay> _getActivitiesForDay(String day) {
    if (_optimizedTimetableData == null) return {};

    final dayData = _optimizedTimetableData![day.toLowerCase()] as List<dynamic>?;
    if (dayData == null) return {};

    Map<String, ActivityDisplay> timeSlotActivities = {};

    for (var activity in dayData) {
      final startTime = _parseTime(activity['startTime']);
      final endTime = _parseTime(activity['endTime']);
      final activityName = (activity['activity'] ?? '').trim().replaceAll(RegExp(r'\bj\b', caseSensitive: false), '');
      final priority = activity['priority'] ?? 'medium';

      if (activityName.isEmpty) continue;

      final durationInSlots = ((endTime - startTime) / 30).ceil();

      for (int time = startTime; time < endTime; time += 30) {
        final hour = (time ~/ 60).toString().padLeft(2, '0');
        final minute = (time % 60).toString().padLeft(2, '0');
        final timeSlot = '$hour:$minute';

        if (time == startTime) {
          timeSlotActivities[timeSlot] = ActivityDisplay(
            name: activityName,
            isFirstSlot: true,
            spanCount: durationInSlots,
            startTime: activity['startTime'],
            endTime: activity['endTime'],
            priority: priority,
            day: day,
          );
        } else {
          timeSlotActivities[timeSlot] = ActivityDisplay(
            name: activityName,
            isFirstSlot: false,
            spanCount: 1,
            startTime: activity['startTime'],
            endTime: activity['endTime'],
            priority: priority,
            day: day,
          );
        }
      }
    }

    return timeSlotActivities;
  }

  int _parseTime(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  Color _getActivityColor(String activity) {
    final hash = activity.hashCode;
    final colors = [
      const Color(0xFFE0F2F7), // Bleu clair pastel
      const Color(0xFFEBF4E3), // Vert clair pastel
      const Color(0xFFFDE4D0), // Orange clair pastel
      const Color(0xFFEDE7F6), // Violet clair pastel
      const Color(0xFFE0F7FA), // Cyan clair pastel
      const Color(0xFFFCE4EC), // Rose clair pastel
      const Color(0xFFEBE9F6), // Indigo clair pastel
      const Color(0xFFF9FBE7), // Jaune clair pastel
    ];
    return colors[hash.abs() % colors.length];
  }

  Future<void> _updateActivityPriority(String day, String activityName, String startTime, String endTime, String newPriority) async {
    try {
      if (_user == null) return;

      // Créer une copie modifiable des données de l'emploi du temps
      final Map<String, dynamic> updatedTimetableData = Map<String, dynamic>.from(_optimizedTimetableData!);

      final dayData = updatedTimetableData[day.toLowerCase()] as List<dynamic>?;
      if (dayData != null) {
        for (var activity in dayData) {
          if (activity['activity'] == activityName &&
              activity['startTime'] == startTime &&
              activity['endTime'] == endTime) {
            activity['priority'] = newPriority;
            break;
          }
        }
      }

      // Mettre à jour l'état local et Firestore
      setState(() {
        _optimizedTimetableData = updatedTimetableData;
      });

      // Mettre à jour dans la collection 'optimized_schedules'
      await FirebaseFirestore.instance
          .collection('optimized_schedules')
          .doc(_user!.uid)
          .update(updatedTimetableData);

      // --- Déclenchement de la notification si la priorité est 'high' ---
      if (newPriority == 'high') {
        final String timeForNotification = "$startTime - $endTime";
        _notificationService.showNotification(
          id: (activityName.hashCode + day.hashCode + startTime.hashCode), // ID unique
          title: 'Priorité élevée pour une activité ! 🚀',
          body: 'Votre activité "${activityName}" est maintenant marquée comme "Très utile" et se déroule de ${timeForNotification}.',
          payload: 'priority_notification',
        );
        print('Notification locale envoyée pour activité "Très utile": $activityName');
      }
      // --- FIN DÉCLENCHEMENT ---

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Priorité mise à jour avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erreur lors de la mise à jour de la priorité: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _showActivityDetails(ActivityDisplay activity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedPriority = activity.priority;
        final List<Map<String, dynamic>> priorityOptions = [
          {'value': 'low', 'label': 'Pas important', 'color': Colors.green},
          {'value': 'medium', 'label': 'Utile', 'color': Colors.orange},
          {'value': 'high', 'label': 'Très utile', 'color': Colors.red},
        ];

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  const Text("Détails de l'activité"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activity.name),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "De ${activity.startTime} à ${activity.endTime}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Modifier la priorité",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: priorityOptions
                              .map((option) => option['value'] as String)
                              .contains(selectedPriority)
                              ? selectedPriority
                              : 'medium',
                          icon: const Icon(Icons.arrow_drop_down),
                          isExpanded: true,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                selectedPriority = newValue;
                              });
                              _updateActivityPriority(
                                activity.day,
                                activity.name,
                                activity.startTime,
                                activity.endTime,
                                newValue,
                              );
                            }
                          },
                          items: priorityOptions.map<DropdownMenuItem<String>>((option) {
                            return DropdownMenuItem<String>(
                              value: option['value'],
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: option['color'],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(option['label']),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Fermer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'très utile':
        return Colors.red;
      case 'medium':
      case 'utile':
        return Colors.orange;
      case 'low':
      case 'pas important':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'Très utile';
      case 'medium':
        return 'Utile';
      case 'low':
        return 'Pas important';
      default:
        return 'Utile';
    }
  }

  // --- Fin des fonctions copiées ---

  @override
  Widget build(BuildContext context) {
    // Vérification de l'utilisateur non connecté
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emploi du Temps Optimisé'),
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
        body: const Center(
          child: Text(
            'Veuillez vous connecter pour voir votre emploi du temps optimisé.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Afficher un indicateur de chargement
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emploi du Temps Optimisé'),
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
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Chargement de votre emploi du temps optimisé..."),
            ],
          ),
        ),
      );
    }

    // Afficher un message si aucune donnée d'emploi du temps n'est trouvée
    if (_optimizedTimetableData == null || _optimizedTimetableData!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emploi du Temps Optimisé'),
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Veuillez d\'abord configurer votre emploi du temps principal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Créer un emploi du temps"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Navigue vers l'écran de configuration de l'emploi du temps
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const TimetableSetupScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Afficher l'emploi du temps optimisé
    final timeSlots = _generateTimeSlots();
    final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emploi du temps optimisé"),
        backgroundColor: Colors.blue[50],
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green, // Indique que c'est l'emploi du temps optimisé
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  "Optimisé",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOptimizedTimetable, // Bouton d'actualisation
            tooltip: "Actualiser l'emploi du temps optimisé",
          ),
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(), // Ouvre le Drawer
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: MediaQuery.of(context).size.width * 1.8, // Permet le défilement horizontal
            decoration: BoxDecoration( // Ajout d'une bordure autour de tout le tableau
              border: Border.all(color: Colors.grey[300]!, width: 1.0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // En-têtes du tableau (Horaires et Jours)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue[100], // Couleur de fond pour les en-têtes
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        padding: const EdgeInsets.all(8),
                        child: const Text(
                          "Horaires",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ...days.map((day) => Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.blue[200]!, width: 1.0), // Bordure plus visible entre les jours
                                ),
                              ),
                              child: Text(
                                day.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ))
                          .toList(),
                    ],
                  ),
                ),
                // Contenu du tableau (activités)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: timeSlots.map((timeSlot) {
                        return Container(
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Colonne des horaires
                              Container(
                                width: 80,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  border: Border(
                                    right: BorderSide(color: Colors.grey[300]!, width: 0.5),
                                  ),
                                ),
                                child: Text(
                                  timeSlot,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Colonnes des jours (activités)
                              ...days.map((day) {
                                final dayActivities = _getActivitiesForDay(day);
                                final activity = dayActivities[timeSlot];

                                return Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: activity != null
                                          ? () {
                                              print('Clic sur activité: ${activity.name} à $timeSlot pour $day');
                                              _showActivityDetails(activity);
                                            }
                                          : null,
                                      highlightColor: Colors.blue.withOpacity(0.2),
                                      splashColor: Colors.blue.withOpacity(0.3),
                                      child: Container(
                                        height: 60,
                                        margin: const EdgeInsets.all(0.5), // Réduire la marge pour des cellules plus jointives
                                        decoration: BoxDecoration(
                                          color: activity != null ? _getActivityColor(activity.name) : Colors.white, // Fond blanc pour les cellules vides
                                          borderRadius: BorderRadius.circular(4), // Bords légèrement arrondis
                                          border: Border.all(
                                            color: Colors.grey[200]!, // Bordures légères pour chaque cellule
                                            width: 0.8,
                                          ),
                                        ),
                                        child: activity != null
                                            ? Padding( // Utiliser Padding au lieu de Container pour le texte
                                                padding: const EdgeInsets.all(4.0),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (activity.isFirstSlot) ...[
                                                      Text(
                                                        activity.name,
                                                        style: const TextStyle(
                                                          fontSize: 10, // Taille de police légèrement augmentée
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black, // Couleur plus foncée
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 2, // Limiter à 2 lignes pour éviter le débordement
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (activity.spanCount > 1) // Afficher l'heure seulement si l'activité s'étend sur plusieurs créneaux
                                                        Text(
                                                          "${activity.startTime}-${activity.endTime}",
                                                          style: const TextStyle(
                                                            fontSize: 8, // Police plus petite pour les heures
                                                            color: Colors.black54,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                    ],
                                                  ],
                                                ),
                                              )
                                            : const SizedBox.expand(), // Étendre pour remplir la cellule vide
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TimetableSetupScreen()),
          );
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit, size: 36.0),
        tooltip: "Modifier l'emploi du temps original",
      ),
    );
  }
}
