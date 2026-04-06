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
  bool _esPremium = false;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarDecks();
  }

  Future<void> _mostrarDialogoCodigo() async {
    final ctrl = TextEditingController();
    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Código de acceso'),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Ingresa el código'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verificar'),
            ),
          ],
        ),
      );
      if (confirmar == true &&
          ctrl.text.trim().toUpperCase() == 'QUIZDECKPRO') {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirestoreService().activarPremium(uid);
          if (mounted) {
            _cargarDecks();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✦ Premium activado'),
                backgroundColor: Color(0xFF2D9E6B),
              ),
            );
          }
        }
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _cargarDecks() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final results = await Future.wait([
      FirestoreService().obtenerMisDecks(uid),
      FirestoreService().obtenerEsPremium(uid),
    ]);
    setState(() {
      _misDecks = results[0] as List<Map<String, dynamic>>;
      _esPremium = results[1] as bool;
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
                GestureDetector(
                  onTap: () {
                    _tapCount++;
                    if (_tapCount >= 20) {
                      _tapCount = 0;
                      _mostrarDialogoCodigo();
                    }
                  },
                  child: const Text('Mis mazos',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F0E0C))),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _StatCard(
                        label: 'Mazos',
                        value: '${_misDecks.length}',
                        sub: _esPremium ? 'ilimitados' : 'de 3 gratis',
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
                    color: _esPremium
                        ? const Color(0xFFFFF4E6)
                        : const Color(0xFFF0EDE6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _esPremium
                            ? const Color(0xFFF5A623)
                            : const Color(0xFFE4E0D6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _esPremium
                                  ? '✦ Plan Premium · Mazos ilimitados'
                                  : 'Plan Gratis · ${_misDecks.length} de 3 mazos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _esPremium
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _esPremium
                                    ? const Color(0xFFB87A00)
                                    : null,
                              ),
                            ),
                            if (!_esPremium) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: (_misDecks.length / 3)
                                      .clamp(0.0, 1.0),
                                  backgroundColor:
                                      const Color(0xFFE4E0D6),
                                  valueColor:
                                      const AlwaysStoppedAnimation<
                                              Color>(
                                          Color(0xFFF5A623)),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _esPremium
                            ? null
                            : () async {
                                final activado =
                                    await mostrarDialogoPremium(
                                        context);
                                if (activado) _cargarDecks();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _esPremium
                              ? const Color(0xFF2D9E6B)
                              : const Color(0xFFE85D3A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF2D9E6B),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        child: Text(
                            _esPremium ? '✦ Activo' : '✦ Premium',
                            style: const TextStyle(
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

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  List<Map<String, dynamic>> _todosDecks = [];
  List<Map<String, dynamic>> _decksFiltrados = [];
  bool _cargando = true;
  final _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDecks();
    _busquedaCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDecks() async {
    setState(() => _cargando = true);
    final decks = await FirestoreService().obtenerMazosPublicos();
    setState(() {
      _todosDecks = decks;
      _decksFiltrados = decks;
      _cargando = false;
    });
  }

  void _filtrar() {
    final q = _busquedaCtrl.text.toLowerCase();
    setState(() {
      _decksFiltrados = q.isEmpty
          ? _todosDecks
          : _todosDecks
              .where((d) =>
                  (d['titulo'] ?? '').toLowerCase().contains(q) ||
                  (d['categoria'] ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarDecks,
          color: const Color(0xFFE85D3A),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Explorar mazos',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text(
                          'Mazos creados por la comunidad',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A7770))),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _busquedaCtrl,
                        decoration: InputDecoration(
                          hintText:
                              'Buscar por tema, materia…',
                          hintStyle: const TextStyle(
                              color: Color(0xFF7A7770)),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF7A7770)),
                          suffixIcon:
                              _busquedaCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.clear,
                                          size: 18),
                                      onPressed: () =>
                                          _busquedaCtrl.clear(),
                                    )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFE4E0D6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFE4E0D6)),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (_cargando)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE85D3A)),
                  ),
                )
              else if (_decksFiltrados.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            size: 48,
                            color: Color(0xFF7A7770)),
                        const SizedBox(height: 12),
                        Text(
                          _busquedaCtrl.text.isEmpty
                              ? 'No hay mazos públicos aún'
                              : 'Sin resultados para "${_busquedaCtrl.text}"',
                          style: const TextStyle(
                              color: Color(0xFF7A7770)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: _ExplorarDeckCard(
                            deck: _decksFiltrados[i]),
                      ),
                      childCount: _decksFiltrados.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplorarDeckCard extends StatelessWidget {
  final Map<String, dynamic> deck;
  const _ExplorarDeckCard({required this.deck});

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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final mazo = await FirestoreService()
                    .obtenerMazoCompleto(deck);
                if (mazo == null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                        builder: (_) => StudyScreen(mazo: mazo)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F0E0C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Estudiar',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// PAYWALL PREMIUM
// ═══════════════════════════════════════
Future<bool> mostrarDialogoPremium(BuildContext context) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PremiumSheet(),
  );
  return resultado == true;
}

class _PremiumSheet extends StatefulWidget {
  const _PremiumSheet();

  @override
  State<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<_PremiumSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E0D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE85D3A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('✦',
                    style: TextStyle(
                        fontSize: 28, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('QuizDeck Premium',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Desbloquea todo el potencial de QuizDeck',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF7A7770))),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE85D3A), Color(0xFFFF8C5A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plan Premium',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('S/. 4',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Padding(
                        padding:
                            EdgeInsets.only(bottom: 6, left: 4),
                        child: Text('/mes',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...[
                    'Mazos ilimitados',
                    'Acceso a todos los mazos públicos',
                    'Sin anuncios',
                    'Soporte prioritario',
                  ].map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(f,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Pago próximamente disponible')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D3A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Suscribirme por S/. 4/mes',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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