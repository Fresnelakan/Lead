import 'package:flutter/material.dart';

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.developer_mode, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text(
              'Page des Applications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 10),
            Text(
              'Contenu à venir ici...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
