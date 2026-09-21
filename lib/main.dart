import 'package:flutter/material.dart';

import 'screens/match_demo_screen.dart';

void main() {
  runApp(const PeladinhasApp());
}

class PeladinhasApp extends StatelessWidget {
  const PeladinhasApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF167A45);

    return MaterialApp(
      title: 'Peladinhas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
        scaffoldBackgroundColor: const Color(0xFFF6F8F4),
        useMaterial3: true,
      ),
      home: const MatchDemoScreen(),
    );
  }
}
