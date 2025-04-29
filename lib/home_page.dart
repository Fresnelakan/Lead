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

  void _addTimeSlot() {
    setState(() {
      _timeSlots[_currentDayIndex].add(TimeSlot());
    });
  }

  void _nextDay() async {
    // Marquez la fonction comme async
    if (_currentDayIndex < _days.length - 1) {
      setState(() => _currentDayIndex++);
    } else {
      // L'utilisateur a terminé la saisie de tous les jours

      // 1. Convertir les données de l'emploi du temps en JSON
      final String jsonTimetable = _buildJsonTimetable();

      // 2. Envoyer le JSON à Firebase Firestore
      await _sendTimetableToFirestore(jsonTimetable);

      // 3. Naviguer vers la page de l'emploi du temps optimisé
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OptimizedSchedulePage(),
        ), // Naviguer vers la nouvelle page
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
                    ),
              ),
            ),
            ElevatedButton(
              onPressed: _addTimeSlot,
              child: const Text("+ Ajouter une plage horaire"),
            ),
            ElevatedButton(
              onPressed: _nextDay,
              child: Text(
                _currentDayIndex == _days.length - 1
                    ? "Terminer"
                    : "Jour suivant",
              ),
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

  const TimeSlotEntry({super.key, required this.timeSlot});

  @override
  State<TimeSlotEntry> createState() => _TimeSlotEntryState();
}

class _TimeSlotEntryState extends State<TimeSlotEntry> {
  @override
  Widget build(BuildContext context) {
    return Card(
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
                    if (time != null)
                      setState(() => widget.timeSlot.startTime = time);
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
                    if (time != null)
                      setState(() => widget.timeSlot.endTime = time);
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
