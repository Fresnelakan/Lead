import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart'; // Importez home_page.dart pour accéder à TimetableSetupScreen si elle n'est pas dans le même fichier

class OptimizedSchedulePage extends StatefulWidget {
  const OptimizedSchedulePage({super.key});

  @override
  State<OptimizedSchedulePage> createState() => _OptimizedSchedulePageState();
}

class _OptimizedSchedulePageState extends State<OptimizedSchedulePage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    // Vérification de l'utilisateur non connecté en haut pour une gestion plus propre
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emploi du Temps Optimisé'),
          backgroundColor: Colors.blue[50],
          elevation: 0,
          foregroundColor: Colors.black,
          // Bouton hamburger pour ouvrir le Drawer
          // Un Builder est nécessaire ici car OptimizedSchedulePage n'est pas un Scaffold direct,
          // mais est enfant d'un Scaffold (HomePage) qui possède le Drawer.
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(), // Ouvre le Drawer du Scaffold parent
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Veuillez vous connecter pour voir votre emploi du temps optimisé.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emploi du Temps Optimisé'),
        backgroundColor: Colors.blue[50],
        elevation: 0,
        foregroundColor: Colors.black,
        // Bouton hamburger pour ouvrir le Drawer
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(), // Ouvre le Drawer du Scaffold parent
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('optimized_schedules')
            .doc(_user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
            return const Center(
              child: Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
              ),
            );
          }

          final Map<String, dynamic>? data =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null || data.isEmpty) {
            return const Center(
              child: Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
              ),
            );
          }

          final List<DataRow> rows = [];
          data.forEach((jour, activites) {
            if (jour == '_metadata') return; // Ignorer les métadonnées

            if (activites is List) {
              for (var tache in activites) {
                final String activityName = tache['activity']?.toString() ?? 'N/A';
                final String startTime = tache['startTime']?.toString() ?? 'N/A';
                final String endTime = tache['endTime']?.toString() ?? 'N/A';

                rows.add(
                  DataRow(
                    cells: [
                      DataCell(Text(jour[0].toUpperCase() + jour.substring(1))),
                      DataCell(
                        Text('${startTime} - ${endTime}'),
                      ),
                      DataCell(Text(activityName)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TimetableSetupScreen(
                onSubmitted: () {
                  // Ajoutez ici la logique à exécuter lors de la soumission, par exemple :
                  Navigator.pop(context);
                },
              ),
            ),
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
