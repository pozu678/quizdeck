import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_service.dart';
import '../study_screen.dart';
import '../widgets/paywall_sheet.dart';

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  List<Map<String, dynamic>> _todosDecks = [];
  List<Map<String, dynamic>> _decksFiltrados = [];
  bool _cargando = true;
  bool _esPremium = false;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final results = await Future.wait([
      FirestoreService().obtenerMazosPublicos(),
      if (uid != null)
        FirestoreService().obtenerEsPremium(uid)
      else
        Future.value(false),
    ]);
    setState(() {
      _todosDecks = results[0] as List<Map<String, dynamic>>;
      _decksFiltrados = _todosDecks;
      _esPremium = results[1] as bool;
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Explorar mazos',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Mazos creados por la comunidad',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A7770))),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _busquedaCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar por tema, materia…',
                          hintStyle: const TextStyle(
                              color: Color(0xFF7A7770)),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF7A7770)),
                          suffixIcon: _busquedaCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
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
                      mainAxisAlignment:
                          MainAxisAlignment.center,
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
                  padding: const EdgeInsets.fromLTRB(
                      24, 0, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: _ExplorarDeckCard(
                          deck: _decksFiltrados[i],
                          esPremium: _esPremium,
                        ),
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
  final bool esPremium;
  const _ExplorarDeckCard(
      {required this.deck, required this.esPremium});

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
              onPressed: () =>
                  _estudiar(context),
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

  Future<void> _estudiar(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Verificar límite de sesiones para usuarios gratuitos
    if (!esPremium && uid != null) {
      final puede = await FirestoreService().puedeEstudiar(uid);
      if (!puede) {
        if (context.mounted) {
          await _mostrarLimiteDiario(context, uid);
        }
        return;
      }
    }

    final mazo = await FirestoreService().obtenerMazoCompleto(deck);
    if (mazo == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Este mazo no tiene preguntas aún')),
      );
      return;
    }
    if (mazo != null && context.mounted) {
      if (uid != null && !esPremium) {
        await FirestoreService().registrarSesion(uid);
        if (!context.mounted) return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudyScreen(
            mazo: mazo,
            esPremium: esPremium,
            deckId: deck['id'] as String?,
          ),
        ),
      );
    }
  }

  Future<void> _mostrarLimiteDiario(
      BuildContext context, String uid) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Límite diario alcanzado'),
        content: const Text(
            'Has alcanzado tu límite de 5 sesiones diarias. ¡Hazte Premium para estudiar ilimitadamente!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Anuncios próximamente')),
              );
            },
            child: const Text('Ver anuncio (+3 sesiones)'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (context.mounted) {
                await mostrarDialogoPremium(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85D3A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Premium'),
          ),
        ],
      ),
    );
  }
}
