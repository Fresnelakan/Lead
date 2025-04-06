import 'package:flutter/material.dart';
import 'package:lead/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Liste des couleurs de fond pour chaque page
  final List<Color> backgroundColors = [
    const Color.fromARGB(255, 194, 238, 170),    // Vert pour la page 1
    const Color.fromARGB(255, 255, 186, 206),     // Rose pour la page 2
    const Color.fromARGB(255, 253, 218, 128),   // Jaune pour la page 3
    const Color.fromARGB(255, 198, 226, 255),     // Bleu pour la page 4
  ];

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/onboard1.png",
      "title": "Reprenez le contrôle de votre temps",
      "subtitle": "Organisez votre emploi du temps facilement et optimisez votre quotidien pour plus d'efficacité.",
    },
    {
      "image": "assets/onboard2.png",
      "title": "Saisie simple et personnalisée",
      "subtitle": "Créez votre emploi du temps en quelques clics, ajoutez vos activités spécifiques et visualisez votre semaine.",
    },
    {
      "image": "assets/onboard3.png",
      "title": "Ne manquez plus rien d'important",
      "subtitle": "Visualisez clairement vos engagements et restez organisé pour atteindre vos objectifs",
    },
    {
      "image": "assets/onboard4.png",
      "title": "Prêt à organiser votre temps ?",
      "subtitle": "Inscrivez-vous et découvrez une nouvelle façon de gérer votre emploi du temps.",
    },
  ];

  void _finishOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true); // Correction: 'onboarding_seen' au lieu de 'onboarding_done'

    if (!mounted) return;

    Navigator.of(context).pushReplacement( // Correction: Utilisation de Navigator.of(context)
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }


    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: onboardingData.length,
              itemBuilder: (context, index) {
                final data = onboardingData[index];
                return Container(
                  color: backgroundColors[index],
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            data['image']!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          data['title']!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Couleur noire rétablie
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data['subtitle']!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 13, 12, 12), // Couleur grise rétablie
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: onboardingData.asMap().entries.map((entry) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: _currentPage == entry.key ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: _currentPage == entry.key
                                    ? Colors.white
                                    : Color.fromRGBO(255, 255, 255, 0.5), // Correction withOpacity
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: backgroundColors[_currentPage],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text(
                        "Ignorer",
                        style: TextStyle(color: Colors.black), // Couleur noire rétablie
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == onboardingData.length - 1) {
                          _finishOnboarding();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == onboardingData.length - 1 ? "Commencer" : "Suivant",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
}