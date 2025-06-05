import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    // Vous pouvez ajouter ici une logique pour charger les données initiales si nécessaire
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

    // Écouter les changements dans Firestore pour l'emploi du temps optimisé de l'utilisateur
    return Scaffold(
      appBar: AppBar(title: const Text('Emploi du Temps Optimisé')),
      body: StreamBuilder<DocumentSnapshot>(
        // Assurez-vous que la collection et le document correspondent à l'endroit où vous stockez l'emploi du temps optimisé
        // Nous utiliserons l'UID de l'utilisateur comme nom de document
        stream:
            FirebaseFirestore.instance
                .collection('optimized_schedules')
                .doc(_user!.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
              ),
            );
          }

          // Les données de l'emploi du temps optimisé sont dans snapshot.data!.data()
          // Elles devraient être sous forme de Map<String, dynamic>
          final Map<String, dynamic>? data =
              snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null || data.isEmpty) {
            return const Center(
              child: Text(
                'Aucun emploi du temps optimisé trouvé pour le moment.',
              ),
            );
          }

          // Construction des lignes du tableau
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
