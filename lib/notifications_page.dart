import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:lead/main.dart'; // Pour accéder à notificationService

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showNotificationSettings(context),
          ),
        ],
      ),
      body: const _NotificationsBody(),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _NotificationSettingsDialog(),
    );
  }
}

class _NotificationsBody extends StatefulWidget {
  const _NotificationsBody();

  @override
  State<_NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<_NotificationsBody> with WidgetsBindingObserver {
  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _localNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFirebaseMessaging();
    _loadPendingNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupFirebaseMessaging() {
    // Écouter les messages Firebase quand l'app est en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted && message.notification != null) {
        _showInAppNotification(message);
      }
    });

    // Écouter quand l'app est ouverte via une notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) {
        _handleNotificationTap(message);
      }
    });
  }

  void _showInAppNotification(RemoteMessage message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.notification?.title ?? 'Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (message.notification?.body != null)
              Text(message.notification!.body!),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Gérer la navigation ou l'action basée sur le contenu de la notification
    print('Notification tapée: ${message.data}');
    // Exemple: naviguer vers une page spécifique
    // Navigator.push(context, MaterialPageRoute(builder: (context) => SpecificPage()));
  }

  Future<void> _loadPendingNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      // Charger les notifications en attente
      await notificationService.listPendingNotifications();
      
      // Simuler quelques notifications locales pour l'exemple
      // En pratique, vous pourriez stocker ces informations dans une base de données locale
      setState(() {
        _localNotifications = [
          {
            'id': 1,
            'title': 'Rappel: Réunion équipe',
            'body': 'Votre réunion commence dans 5 minutes',
            'type': 'schedule',
            'scheduledDate': DateTime.now().add(const Duration(minutes: 5)),
            'isActive': true,
          },
          {
            'id': 2,
            'title': 'Rappel: Pause déjeuner',
            'body': 'Il est temps de prendre votre pause déjeuner',
            'type': 'schedule',
            'scheduledDate': DateTime.now().add(const Duration(hours: 2)),
            'isActive': true,
          },
        ];
      });
    } catch (e) {
      print('Erreur chargement notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Onglets pour filtrer les notifications
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: null,
            tabs: const [
              Tab(text: '📱 Récentes'),
              Tab(text: '⏰ Programmées'),
              Tab(text: '🔔 Firebase'),
            ],
            onTap: (index) => setState(() => _selectedTabIndex = index),
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),
        
        // Contenu des onglets
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildRecentNotifications();
      case 1:
        return _buildScheduledNotifications();
      case 2:
        return _buildFirebaseNotifications();
      default:
        return _buildRecentNotifications();
    }
  }

  Widget _buildRecentNotifications() {
    // Combinaison de toutes les notifications récentes
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNotificationCard(
          title: 'Système de notifications activé',
          body: 'Vos rappels d\'emploi du temps sont maintenant configurés',
          time: DateTime.now().subtract(const Duration(minutes: 5)),
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _buildNotificationCard(
          title: 'Emploi du temps mis à jour',
          body: 'Votre planning de la semaine a été optimisé',
          time: DateTime.now().subtract(const Duration(hours: 1)),
          icon: Icons.schedule,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildScheduledNotifications() {
    if (_localNotifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune notification programmée',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Configurez votre emploi du temps pour recevoir des rappels',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _localNotifications.length,
      itemBuilder: (context, index) {
        final notification = _localNotifications[index];
        return _buildScheduledNotificationCard(notification);
      },
    );
  }

  Widget _buildFirebaseNotifications() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Connectez-vous pour voir vos notifications'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erreur: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucune notification Firebase',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index].data() as Map<String, dynamic>;
            return _buildFirebaseNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String body,
    required DateTime time,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(body),
        trailing: Text(
          DateFormat('HH:mm').format(time),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildScheduledNotificationCard(Map<String, dynamic> notification) {
    final bool isActive = notification['isActive'] ?? false;
    final DateTime scheduledDate = notification['scheduledDate'];
    final bool isPast = scheduledDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPast 
              ? Colors.grey.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: Icon(
            isPast ? Icons.history : Icons.schedule,
            color: isPast ? Colors.grey : Colors.orange,
          ),
        ),
        title: Text(
          notification['title'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isPast ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['body'] ?? ''),
            const SizedBox(height: 4),
            Text(
              'Programmée pour: ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDate)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: isActive && !isPast
            ? IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _cancelNotification(notification['id']),
              )
            : Icon(
                isPast ? Icons.check : Icons.schedule,
                color: isPast ? Colors.green : Colors.grey,
              ),
      ),
    );
  }

  Widget _buildFirebaseNotificationCard(Map<String, dynamic> notification) {
    final Timestamp? createdAt = notification['createdAt'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.cloud, color: Colors.white),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(notification['body'] ?? ''),
        trailing: createdAt != null
            ? Text(
                DateFormat('dd/MM HH:mm').format(createdAt.toDate()),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            : null,
      ),
    );
  }

  Future<void> _cancelNotification(int id) async {
    try {
      await notificationService.cancelNotification(id);
      setState(() {
        _localNotifications.removeWhere((notif) => notif['id'] == id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification annulée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _NotificationSettingsDialog extends StatefulWidget {
  const _NotificationSettingsDialog();

  @override
  State<_NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<_NotificationSettingsDialog> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override

  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('⚙️ Paramètres de notification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Notifications activées'),
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
          ),
          SwitchListTile(
            title: const Text('Son'),
            value: _soundEnabled,
            onChanged: _notificationsEnabled
                ? (value) => setState(() => _soundEnabled = value)
                : null,
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: _vibrationEnabled,
            onChanged: _notificationsEnabled
                ? (value) => setState(() => _vibrationEnabled = value)
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            // Sauvegarder les paramètres
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paramètres sauvegardés')),
            );
          },
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }
}