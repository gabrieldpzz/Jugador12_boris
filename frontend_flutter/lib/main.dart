// lib/main.dart
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'services/session_service.dart';

// Flags globales (compat con tu código actual)
bool isLoggedIn = false;
String? currentUserEmail;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService.init();
  // Sincroniza flags globales
  isLoggedIn = SessionService.isLoggedIn.value;
  currentUserEmail = SessionService.email;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Escucha cambios de sesión para reflejar en flags globales si cambian
  @override
  void initState() {
    super.initState();
    SessionService.isLoggedIn.addListener(() {
      setState(() {
        isLoggedIn = SessionService.isLoggedIn.value;
        currentUserEmail = SessionService.email;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarketShirt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
