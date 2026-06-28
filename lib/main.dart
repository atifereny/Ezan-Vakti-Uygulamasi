import 'package:flutter/material.dart';
import 'app.dart';

void main() async {
  // Plugin'lerin kullanılabilmesi için Flutter binding'lerini başlat
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EzanVaktiApp());
}
