import 'package:flutter/material.dart';
import 'apps_page.dart';
import 'notifications_page.dart';
import 'optimized_schedule_page.dart';
import 'dart:convert'; // Pour l'encodage JSON
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1; // Index par défaut pour Schedule
  final List<Widget> _pages = [
    const AppsPage(),
    const TimetableSetupScreen(), // Écran principal de saisie
    const NotificationsPage(),
    const OptimizedSchedulePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor:
            Colors.black, // Couleur des icônes/texte sélectionnés
        unselectedItemColor:
            Colors.grey[700], // Couleur des icônes/texte non sélectionnés
        backgroundColor: Colors.white, // Couleur de fond de la barre
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Apps'),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            // Nouvel élément pour la page optimisée
            icon: Icon(
              Icons.check_circle_outline,
            ), // Icône exemple, choisissez celle qui convient le mieux
            label: 'Optimisé', // Libellé pour le nouvel onglet
          ),
        ],
      ),
    );
  }
}

class TimetableSetupScreen extends StatefulWidget {
  const TimetableSetupScreen({super.key});

  @override
  State<TimetableSetupScreen> createState() => _TimetableSetupScreenState();
}

class _TimetableSetupScreenState extends State<TimetableSetupScreen> {
  final List<String> _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  int _currentDayIndex = 0;
  final List<List<TimeSlot>> _timeSlots = List.generate(7, (_) => []);
  final Set<int> _errorIndexes = {};

  void _addTimeSlot() {
  final slots = _timeSlots[_currentDayIndex];
  // 1. Vérifier que la tâche précédente est remplie
    if (slots.isNotEmpty && slots.last.activity.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir la tâche précédente avant d\'en ajouter une nouvelle.'),
          backgroundColor: Colors.orange,
        ),
      );
      _setErrorIndexes({slots.length - 1});
      return;
    }

  // 2. Vérifier que l'heure de fin > heure de début
    if (slots.isNotEmpty &&
        !_isEndAfterStart(slots.last.startTime, slots.last.endTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'heure de fin doit être après l\'heure de début.'),
          backgroundColor: Colors.red,
        ),
      );
      _setErrorIndexes({slots.length - 1});
      return;
    }

  // 2. Heure de début = heure de fin précédente, sinon heure actuelle
  TimeOfDay start = TimeOfDay.now();
  if (slots.isNotEmpty) {
    start = slots.last.endTime;
  }
  setState(() {
    slots.add(TimeSlot()
      ..startTime = start
      ..endTime = start
    );
    _errorIndexes.clear();
  });
}

   // Vérifie si end > start
  bool _isEndAfterStart(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes > startMinutes;
  }

  // Vérifie s'il y a chevauchement dans la liste des créneaux
  Set<int> _findOverlappingSlots(List<TimeSlot> slots) {
    Set<int> overlapping = {};
    for (int i = 0; i < slots.length; i++) {
      final aStart = slots[i].startTime.hour * 60 + slots[i].startTime.minute;
      final aEnd = slots[i].endTime.hour * 60 + slots[i].endTime.minute;
      for (int j = i + 1; j < slots.length; j++) {
        final bStart = slots[j].startTime.hour * 60 + slots[j].startTime.minute;
        final bEnd = slots[j].endTime.hour * 60 + slots[j].endTime.minute;
        // Chevauchement si l'un commence avant la fin de l'autre et finit après le début de l'autre
        if (aStart < bEnd && aEnd > bStart) {
          overlapping.add(i);
          overlapping.add(j);
        }
      }
    }
    return overlapping;
  }

  // Pour gérer l'affichage des erreurs (clignotement)
  void _setErrorIndexes(Set<int> indexes) {
    setState(() {
      _errorIndexes.clear();
      _errorIndexes.addAll(indexes);
    });
    // Animation simple : retire l'erreur après 1 seconde si corrigé
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _errorIndexes.clear());
    });
  }


  void _nextDay() async {
    final slots = _timeSlots[_currentDayIndex];
    // Vérifier qu'il n'y a pas de chevauchement
    final overlapping = _findOverlappingSlots(slots);
    if (overlapping.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il y a des chevauchements entre vos tâches.'),
          backgroundColor: Colors.red,
        ),
      );
      _setErrorIndexes(overlapping);
      return;
    }

    if (_currentDayIndex < _days.length - 1) {
      setState(() => _currentDayIndex++);
    } else {
      // ...existing code pour envoyer à Firestore et naviguer...
      final String jsonTimetable = _buildJsonTimetable();
      await _sendTimetableToFirestore(jsonTimetable);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OptimizedSchedulePage(),
        ),
      );
    }
  }

  String _buildJsonTimetable() {
    final Map<String, dynamic> timetableData = {};
    final List<String> days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    for (int i = 0; i < _timeSlots.length; i++) {
      final List<Map<String, dynamic>> daySchedule = [];
      for (var timeSlot in _timeSlots[i]) {
        daySchedule.add({
          'startTime': timeSlot.startTime.format(
            context,
          ), // Formattez l'heure comme vous le souhaitez
          'endTime': timeSlot.endTime.format(
            context,
          ), // Formattez l'heure comme vous le souhaitez
          'activity': timeSlot.activity,
        });
      }
      timetableData[days[i].toLowerCase()] =
          daySchedule; // Utilisez les noms des jours en minuscules comme clés
    }

    return jsonEncode(timetableData); // Convertir la Map en chaîne JSON
  }

  Future<void> _sendTimetableToFirestore(String jsonTimetable) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Gérer le cas où l'utilisateur n'est pas connecté (ne devrait pas arriver dans cette partie de l'app)
        print(
          'Utilisateur non connecté, impossible d\'envoyer l\'emploi du temps.',
        );
        return;
      }

      // Obtenir une référence à la collection et au document
      final timetableRef = FirebaseFirestore.instance
          .collection(
            'user_timetables',
          ) // Nom de la collection pour les emplois du temps bruts
          .doc(
            user.uid,
          ); // Utiliser l'UID de l'utilisateur comme ID de document

      // Convertir la chaîne JSON en Map pour Firestore
      final Map<String, dynamic> timetableData = jsonDecode(jsonTimetable);

      // Envoyer les données à Firestore
      await timetableRef.set(timetableData);

      print(
        'Emploi du temps envoyé avec succès à Firestore pour l\'utilisateur ${user.uid}',
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'emploi du temps à Firestore: $e');
      // Afficher un message d'erreur à l'utilisateur si nécessaire
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de l\'emploi du temps : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_days[_currentDayIndex])),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Nous allons prendre votre emploi du temps...",
              style: TextStyle(fontSize: 20),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _timeSlots[_currentDayIndex].length,
                itemBuilder:
                    (context, index) => TimeSlotEntry(
                      timeSlot: _timeSlots[_currentDayIndex][index],
                      error: _errorIndexes.contains(index),
                    ),
              ),
            ),
            Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text("Ajouter une tâche"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _addTimeSlot,
      ),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          _currentDayIndex == _days.length - 1 ? "Terminer" : "Jour suivant",
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _nextDay,
      ),
    ),
  ],
),
          ],
        ),
      ),
    );
  }
}

class TimeSlot {
  TimeOfDay startTime = TimeOfDay.now();
  TimeOfDay endTime = TimeOfDay.now();
  String activity = '';
}

class TimeSlotEntry extends StatefulWidget {
  final TimeSlot timeSlot;
  final bool error;

  const TimeSlotEntry({super.key, required this.timeSlot, this.error = false});

  @override
  State<TimeSlotEntry> createState() => _TimeSlotEntryState();
}

class _TimeSlotEntryState extends State<TimeSlotEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _colorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.red[100],
    ).animate(_controller);

    if (widget.error) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TimeSlotEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.error && _controller.isAnimating) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Card(
          color: widget.error ? _colorAnimation.value : Colors.white,
          shape: RoundedRectangleBorder(
            side: widget.error
                ? const BorderSide(color: Colors.red, width: 2)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text("De :"),
                    TextButton(
                      child: Text(widget.timeSlot.startTime.format(context)),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: widget.timeSlot.startTime,
                        );
                        if (time != null) {
                          setState(() => widget.timeSlot.startTime = time);
                        }
                      },
                    ),
                    const Text("À :"),
                    TextButton(
                      child: Text(widget.timeSlot.endTime.format(context)),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: widget.timeSlot.endTime,
                        );
                        if (time != null) {
                          setState(() => widget.timeSlot.endTime = time);
                        }
                      },
                    ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Activité"),
                  onChanged: (value) => widget.timeSlot.activity = value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class TimetableViewScreen extends StatelessWidget {
  const TimetableViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emploi du temps")),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Heure')),
            DataColumn(label: Text('Lundi')),
            DataColumn(label: Text('Mardi')),
            DataColumn(label: Text('Mercredi')),
            DataColumn(label: Text('Jeudi')),
            DataColumn(label: Text('Vendredi')),
            DataColumn(label: Text('Samedi')),
            DataColumn(label: Text('Dimanche')),
          ],
          rows: const [], // À remplir avec les données
        ),
      ),
    );
  }
}
