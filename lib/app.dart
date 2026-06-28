import 'package:flutter/material.dart';
import 'presentation/screens/main_screen.dart';

class EzanVaktiApp extends StatelessWidget {
  const EzanVaktiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezan Vakti',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
