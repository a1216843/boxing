import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/speaker.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(BoxingCoachApp(speaker: Speaker()));
}

class BoxingCoachApp extends StatelessWidget {
  const BoxingCoachApp({super.key, required this.speaker});

  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미트 콜',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
      ),
      home: HomeScreen(speaker: speaker),
    );
  }
}
