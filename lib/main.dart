import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'study_screen.dart';
import 'auth_screen.dart';
import 'firestore_service.dart';
import 'crear_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style, color: Colors.white),
            label: 'Mis mazos',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Colors.white),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box, color: Colors.white),
            label: 'Crear',
          ),
        ],
      ),
    );
  }
}

class MisMazosScreen extends StatefulWidget {
  const MisMazosScreen({super.key});

  @override
  State<MisMazosScreen> createState() => _MisMazosScreenState();
}

class _MisMazosScreenState extends State<MisMazosScreen> {
  List<Map<String, dynamic>> _misDecks = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDecks();
  }

  Future<void> _cargarDecks() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final decks = await FirestoreService().obtenerMisDecks(uid);
    setState(() {
      _misDecks = decks;
      _cargando = false;
    });
  }

  Future<void> _eliminarMazo(String deckId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar mazo?'),
        content: const Text(
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE85D3A)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await FirestoreService().eliminarMazo(deckId);
      _cargarDecks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarDecks,
          color: const Color(0xFFE85D3A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Hola, ${FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'Estudiante'} 👋',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF7A7770)),
                ),
                const SizedBox(height: 4),
                const Text('Mis mazos',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F0E0C))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _StatCard(
                        label: 'Mazos',
                        value: '${_misDecks.length}',
                        sub: 'de 3 gratis',
                        color: const Color(0xFFE85D3A)),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Acierto',
                        value: '—',
                        sub: 'promedio',
                        color: const Color(0xFF2D9E6B)),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Racha',
                        value: '0',
                        sub: 'días',
                        color: const Color(0xFFE85D3A)),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Creados por mí',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Tus bancos de preguntas',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A7770))),
                const SizedBox(height: 16),
                if (_cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                          color: Color(0xFFE85D3A)),
                    ),
                  )
                else if (_misDecks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFE4E0D6)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.style_outlined,
                            size: 40,
                            color: Color(0xFF7A7770)),
                        SizedBox(height: 12),
                        Text('Aún no tienes mazos',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3A3832))),
                        SizedBox(height: 6),
                        Text(
                            'Crea tu primer mazo en la pestaña Crear',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7A7770))),
                      ],
                    ),
                  )
                else
                  ..._misDecks.map((deck) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: _FirestoreDeckCard(
                          deck: deck,
                          onEliminar: () =>
                              _eliminarMazo(deck['id'] ?? ''),
                        ),
                      )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDE6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE4E0D6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan Gratis · ${_misDecks.length} de 3 mazos',
                              style: const TextStyle(
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _misDecks.length / 3,
                                backgroundColor:
                                    const Color(0xFFE4E0D6),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFF5A623)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFE85D3A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        child: const Text('✦ Premium',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FirestoreDeckCard extends StatelessWidget {
  final Map<String, dynamic> deck;
  final VoidCallback onEliminar;

  const _FirestoreDeckCard({
    required this.deck,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  deck['categoria'] ?? 'General',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A5FA3)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: deck['esPublico'] == true
                      ? const Color(0xFFEAF7F0)
                      : const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  deck['esPublico'] == true
                      ? 'Público'
                      : 'Privado',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: deck['esPublico'] == true
                          ? const Color(0xFF2D9E6B)
                          : const Color(0xFF7A7770)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            deck['titulo'] ?? 'Sin título',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${deck['descargas'] ?? 0} descargas',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF7A7770)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: onEliminar,
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFE85D3A), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFFE4E0D6)),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                  ),
                  child: const Text('✏️ Editar',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3A3832))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final mazo = await FirestoreService()
                        .obtenerMazoCompleto(deck);
                    if (mazo == null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Este mazo no tiene preguntas aún')),
                      );
                      return;
                    }
                    if (mazo != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudyScreen(mazo: mazo),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0E0C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                  ),
                  child: const Text('Estudiar',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Explorar mazos',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'Miles de preguntas creadas por la comunidad',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A7770))),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por tema, materia, autor…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF7A7770)),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF7A7770)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFE4E0D6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFE4E0D6)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Próximamente más mazos…',
                  style: TextStyle(
                      color: Color(0xFF7A7770))),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E0D6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7A7770))),
          ],
        ),
      ),
    );
  }
}