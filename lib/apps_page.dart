import 'package:flutter/material.dart';

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenue sur Lead !'), // Titre accueillant pour l'étudiant
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Pour que les cartes prennent toute la largeur
          children: [
            // Message d'accueil personnalisé
            Center(
              child: Column(
                children: [
                  const Icon(Icons.school, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  Text(
                    'Salut, cher étudiant ! 👋', // Message de bienvenue personnalisé
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Prêt à optimiser ton emploi du temps et booster ta productivité ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Carte d'action principale : Saisir l'emploi du temps
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commence par optimiser ta semaine !',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enregistre ton emploi du temps actuel pour que l\'IA te propose les meilleures opportunités d\'apprentissage.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Simule l'action, sans réelle navigation pour cette démo statique
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Clique sur l\'onglet "Emploi du temps" pour commencer !')),
                          );
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Enregistrer mon emploi du temps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          textStyle: const TextStyle(fontSize: 17),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Carte "Aperçu de ta Productivité" (statistiques statiques)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aperçu de ta productivité',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green[700]),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(context, '12', 'h', 'Étude dédiée', Icons.book),
                        _buildStatColumn(context, '5', '', 'Révisions suggérées', Icons.lightbulb_outline),
                        _buildStatColumn(context, '80', '%', 'Tâches terminées', Icons.check_circle_outline),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Ces chiffres sont un exemple de ce que Lead te montrera pour suivre tes progrès !',
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Carte "Conseil du Jour" (statique)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              color: Colors.orange[50], // Une couleur différente pour attirer l'attention
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conseil du Jour',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange[800]),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, size: 30, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La meilleure façon de prédire l\'avenir est de le créer ! Commence dès aujourd\'hui !',
                            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                'Lead - Optimisez votre potentiel. Version 1.0', // Petite signature
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fonction utilitaire pour les colonnes de statistiques
  Widget _buildStatColumn(BuildContext context, String value, String unit, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Colors.blueAccent),
        const SizedBox(height: 5),
        Text(
          '$value$unit',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}