import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/role_select_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp();

  // Automatically create/sign in an anonymous Firebase user.
  // This gives the app an authenticated UID that we can use
  // with Firestore security rules.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(const MyApp());
}

// Warm orange seed color - fits a delivery/logistics app,
// and keeps this app visually distinct from the other apps
// in the internship portfolio.
const Color kSeedColor = Color(0xFFF97316);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Parcelo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          foregroundColor: lightScheme.onSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: lightScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      home: const RoleSelectScreen(),
    );
  }
}