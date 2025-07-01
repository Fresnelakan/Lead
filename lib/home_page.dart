import 'package:flutter/material.dart';
import 'apps_page.dart';
import 'notifications_page.dart';
import 'optimized_schedule_page.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1;
  final List<Widget> _pages = [
    const AppsPage(),
    const TimetableSetupScreen(),
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
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[700],
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Apps'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Optimisé'),
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

  String _formatTimeTo24Hour(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _addTimeSlot() {
    final slots = _timeSlots[_currentDayIndex];

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

    if (slots.isNotEmpty && !_isEndAfterStart(slots.last.startTime, slots.last.endTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'heure de fin doit être après l\'heure de début.'),
          backgroundColor: Colors.red,
        ),
      );
      _setErrorIndexes({slots.length - 1});
      return;
    }

    TimeOfDay start = TimeOfDay.now();
    if (slots.isNotEmpty) {
      start = slots.last.endTime;
    }

    setState(() {
      slots.add(TimeSlot()
        ..startTime = start
        ..endTime = start);
      _errorIndexes.clear();
    });
  }

  bool _isEndAfterStart(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes > startMinutes;
  }

  Set<int> _findOverlappingSlots(List<TimeSlot> slots) {
    Set<int> overlapping = {};
    for (int i = 0; i < slots.length; i++) {
      final aStart = slots[i].startTime.hour * 60 + slots[i].startTime.minute;
      final aEnd = slots[i].endTime.hour * 60 + slots[i].endTime.minute;
      for (int j = i + 1; j < slots.length; j++) {
        final bStart = slots[j].startTime.hour * 60 + slots[j].startTime.minute;
        final bEnd = slots[j].endTime.hour * 60 + slots[j].endTime.minute;
        if (aStart < bEnd && aEnd > bStart) {
          overlapping.add(i);
          overlapping.add(j);
        }
      }
    }
    return overlapping;
  }

  void _setErrorIndexes(Set<int> indexes) {
    setState(() {
      _errorIndexes.clear();
      _errorIndexes.addAll(indexes);
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _errorIndexes.clear());
    });
  }

  void _nextDay() async {
    final slots = _timeSlots[_currentDayIndex];
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
      final String jsonTimetable = _buildJsonTimetable();
      await _sendTimetableToFirestore(jsonTimetable);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TimetableViewScreen()),
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
        if (timeSlot.activity.trim().isNotEmpty) {
          daySchedule.add({
            'startTime': _formatTimeTo24Hour(timeSlot.startTime),
            'endTime': _formatTimeTo24Hour(timeSlot.endTime),
            'activity': timeSlot.activity,
            'type': 'course',
          });
        }
      }
      timetableData[days[i].toLowerCase()] = daySchedule;
    }

    return jsonEncode(timetableData);
  }

  Future<void> _sendTimetableToFirestore(String jsonTimetable) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Utilisateur non connecté, impossible d\'envoyer l\'emploi du temps.');
        return;
      }

      final timetableRef = FirebaseFirestore.instance
          .collection('user_timetables')
          .doc(FirebaseAuth.instance.currentUser!.uid);

      final Map<String, dynamic> timetableData = jsonDecode(jsonTimetable);
      await timetableRef.set(timetableData);

      print('Emploi du temps envoyé avec succès à Firestore pour l\'utilisateur ${user.uid}');
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'emploi du temps à Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi de l\'emploi du temps : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlots[_currentDayIndex].removeAt(index);
      _errorIndexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_days[_currentDayIndex]),
        backgroundColor: Colors.blue[50],
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 48, color: Colors.blue[600]),
                      const SizedBox(height: 8),
                      const Text(
                        "Construisons votre emploi du temps optimal",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Jour ${_currentDayIndex + 1} sur ${_days.length}",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _timeSlots[_currentDayIndex].isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              "Aucune tâche programmée",
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Commencez par ajouter une tâche",
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _timeSlots[_currentDayIndex].length,
                        itemBuilder: (context, index) => TimeSlotEntry(
                          timeSlot: _timeSlots[_currentDayIndex][index],
                          error: _errorIndexes.contains(index),
                          onRemove: () => _removeTimeSlot(index),
                          index: index,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
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
                        elevation: 2,
                      ),
                      onPressed: _addTimeSlot,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(_currentDayIndex == _days.length - 1 ? Icons.check : Icons.arrow_forward),
                      label: Text(
                        _currentDayIndex == _days.length - 1 ? "Terminer" : "Jour suivant",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _nextDay,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
  final VoidCallback onRemove;
  final int index;

  const TimeSlotEntry({
    super.key,
    required this.timeSlot,
    this.error = false,
    required this.onRemove,
    required this.index,
  });

  @override
  State<TimeSlotEntry> createState() => _TimeSlotEntryState();
}

class _TimeSlotEntryState extends State<TimeSlotEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.timeSlot.activity);
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
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: widget.error ? _colorAnimation.value : Colors.white,
          shape: RoundedRectangleBorder(
            side: widget.error
                ? const BorderSide(color: Colors.red, width: 2)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: widget.error ? 4 : 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Tâche ${widget.index + 1}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: widget.onRemove,
                      tooltip: "Supprimer cette tâche",
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Début", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: widget.timeSlot.startTime,
                                );
                                if (time != null) {
                                  setState(() => widget.timeSlot.startTime = time);
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16),
                                  const SizedBox(width: 8),
                                  Text(widget.timeSlot.startTime.format(context)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Fin", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: widget.timeSlot.endTime,
                                );
                                if (time != null) {
                                  setState(() => widget.timeSlot.endTime = time);
                                }
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16),
                                  const SizedBox(width: 8),
                                  Text(widget.timeSlot.endTime.format(context)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: "Activité",
                    hintText: "Ex: Cours de mathématiques, Révision, Pause...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.edit),
                  ),
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

class TimetableViewScreen extends StatefulWidget {
  const TimetableViewScreen({super.key});

  @override
  State<TimetableViewScreen> createState() => _TimetableViewScreenState();
}

class _TimetableViewScreenState extends State<TimetableViewScreen> {
  Map<String, dynamic>? timetableData;
  bool isLoading = true;
  bool isOptimized = false;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final optimizedDoc = await FirebaseFirestore.instance
            .collection('optimized_schedules')
            .doc(user.uid)
            .get();

        if (optimizedDoc.exists && optimizedDoc.data() != null) {
          print('✅ Emploi du temps optimisé trouvé');
          setState(() {
            timetableData = optimizedDoc.data();
            isOptimized = true;
            isLoading = false;
          });
        } else {
          print('⚠️ Pas d\'emploi du temps optimisé, chargement de l\'original');
          final originalDoc = await FirebaseFirestore.instance
              .collection('user_timetables')
              .doc(user.uid)
              .get();

          if (originalDoc.exists && originalDoc.data() != null) {
            print('✅ Emploi du temps original trouvé');
            setState(() {
              timetableData = originalDoc.data();
              isOptimized = false;
              isLoading = false;
            });
          } else {
            print('❌ Aucun emploi du temps trouvé');
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Erreur lors du chargement de l\'emploi du temps: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateActivityPriority(String day, String activityName, String startTime, String endTime, String newPriority) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        final dayData = timetableData![day.toLowerCase()] as List<dynamic>?;
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
      });

      final collection = isOptimized ? 'optimized_schedules' : 'user_timetables';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .update(timetableData!);

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

  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int hour = 7; hour <= 22; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      slots.add('${hour.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  Map<String, ActivityDisplay> _getActivitiesForDay(String day) {
    if (timetableData == null) return {};

    final dayData = timetableData![day.toLowerCase()] as List<dynamic>?;
    if (dayData == null) return {};

    Map<String, ActivityDisplay> timeSlotActivities = {};

    for (var activity in dayData) {
      print('Activité pour $day: ${activity['activity']}');
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Emploi du temps"),
          backgroundColor: Colors.blue[50],
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Chargement de votre emploi du temps..."),
            ],
          ),
        ),
      );
    }

    if (timetableData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Emploi du temps"),
          backgroundColor: Colors.blue[50],
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "Aucun emploi du temps trouvé",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Veuillez créer votre emploi du temps d'abord",
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

    final timeSlots = _generateTimeSlots();
    final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

    return Scaffold(
      appBar: AppBar(
        title: Text(isOptimized ? "Emploi du temps optimisé" : "Emploi du temps"),
        backgroundColor: Colors.blue[50],
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (isOptimized)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
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
            onPressed: _loadTimetable,
            tooltip: "Actualiser",
          ),
        ],
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
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 1.8,
            child: Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ...days.map((day) => Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.grey[300]!, width: 0.5),
                                ),
                              ),
                              child: Text(
                                day.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ))
                          ,
                    ],
                  ),
                ),
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
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
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
                                        margin: const EdgeInsets.all(1),
                                        decoration: BoxDecoration(
                                          color: activity != null ? _getActivityColor(activity.name) : Colors.transparent,
                                          borderRadius: activity != null ? BorderRadius.circular(4) : null,
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: activity != null
                                            ? Container(
                                                padding: const EdgeInsets.all(2),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (activity.isFirstSlot) ...[
                                                      Text(
                                                        activity.name,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        "${activity.startTime}-${activity.endTime}",
                                                        style: const TextStyle(
                                                          fontSize: 7,
                                                          color: Colors.black54,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ] else ...[
                                                      Container(
                                                        width: double.infinity,
                                                        height: 2,
                                                        color: Colors.black26,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }),
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
        tooltip: "Modifier l'emploi du temps",
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }
}

class ActivityDisplay {
  final String name;
  final bool isFirstSlot;
  final int spanCount;
  final String startTime;
  final String endTime;
  final String priority;
  final String day;

  ActivityDisplay({
    required this.name,
    required this.isFirstSlot,
    required this.spanCount,
    required this.startTime,
    required this.endTime,
    required this.priority,
    required this.day,
  });
}