import 'package:flutter/material.dart';
import 'apps_page.dart';
import 'notifications_page.dart';


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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: 'Apps',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
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
  final List<String> _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
  int _currentDayIndex = 0;
  final List<List<TimeSlot>> _timeSlots = List.generate(6, (_) => []);

  void _addTimeSlot() {
    setState(() {
      _timeSlots[_currentDayIndex].add(TimeSlot());
    });
  }

  void _nextDay() {
    if (_currentDayIndex < _days.length - 1) {
      setState(() => _currentDayIndex++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TimetableViewScreen()),
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
            const Text("Nous allons prendre votre emploi du temps...", 
              style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: _timeSlots[_currentDayIndex].length,
                itemBuilder: (context, index) => TimeSlotEntry(
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
              child: Text(_currentDayIndex == _days.length - 1 
                  ? "Terminer" 
                  : "Jour suivant"),
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
                    if (time != null) setState(() => widget.timeSlot.startTime = time);
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
                    if (time != null) setState(() => widget.timeSlot.endTime = time);
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
          ],
          rows: const [], // À remplir avec les données
        ),
      ),
    );
  }
}