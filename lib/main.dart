import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'auth_screen.dart';
import 'firestore_service.dart';
import 'crear_screen.dart';
import 'screens/mis_mazos_screen.dart';
import 'screens/explorar_screen.dart';
import 'models/mazo_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  Hive.registerAdapter(MazoLocalAdapter());
  Hive.registerAdapter(PreguntaLocalAdapter());
  Hive.registerAdapter(OpcionLocalAdapter());
  await Hive.openBox<MazoLocal>('mazos_locales');
  await Hive.openBox('app_settings');
  runApp(const QuizDeckApp());
}

class QuizDeckApp extends StatelessWidget {
  const QuizDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizDeck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE85D3A),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF8F4),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAF8F4),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE85D3A),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          FirestoreService().crearUsuario(snapshot.data!);
          return const MainScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MisMazosScreen(),
    ExplorarScreen(),
    CrearScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFFFAF8F4),
        indicatorColor: const Color(0xFF0F0E0C),
        onDestinationSelected: (i) =>
            setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon:
                Icon(Icons.style, color: Colors.white),
            label: 'Mis mazos',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon:
                Icon(Icons.explore, color: Colors.white),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon:
                Icon(Icons.add_box, color: Colors.white),
            label: 'Crear',
          ),
        ],
      ),
    );
  }
}
