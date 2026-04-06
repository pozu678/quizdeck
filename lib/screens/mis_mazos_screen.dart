import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_service.dart';
import '../study_screen.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/settings_sheet.dart';
import 'duelo_screen.dart';

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
  double _kScorePromedio = 0;

  // Modo selección multi-mazo
  bool _modoSeleccion = false;
  final Set<String> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _cargarDecks();
  }

  Future<void> _cargarDecks() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final results = await Future.wait([
      FirestoreService().obtenerMisDecks(uid),
      FirestoreService().obtenerEsPremium(uid),
      FirestoreService().obtenerKScorePromedio(uid),
    ]);
    setState(() {
      _misDecks = results[0] as List<Map<String, dynamic>>;
      _esPremium = results[1] as bool;
      _kScorePromedio = results[2] as double;
      _cargando = false;
    });
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

  Future<void> _eliminarMazo(String deckId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar mazo?'),
        content: const Text('Esta acción no se puede deshacer.'),
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

  void _activarModoSeleccion() {
    if (!_esPremium) {
      mostrarDialogoPremium(context);
      return;
    }
    setState(() {
      _modoSeleccion = true;
      _seleccionados.clear();
    });
  }

  void _cancelarSeleccion() {
    setState(() {
      _modoSeleccion = false;
      _seleccionados.clear();
    });
  }

  void _toggleSeleccion(String deckId) {
    setState(() {
      if (_seleccionados.contains(deckId)) {
        _seleccionados.remove(deckId);
      } else {
        _seleccionados.add(deckId);
      }
    });
  }

  Future<void> _mostrarDialogoModoEstudio() async {
    if (_seleccionados.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona al menos 2 mazos')),
      );
      return;
    }

    final modo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E0D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('¿Cómo quieres estudiar?',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.format_list_numbered,
                    color: Color(0xFF0F0E0C)),
              ),
              title: const Text('En orden',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Mazo por mazo, secuencialmente',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF7A7770))),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pop(ctx, 'orden'),
            ),
            const Divider(color: Color(0xFFE4E0D6)),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shuffle,
                    color: Color(0xFF0F0E0C)),
              ),
              title: const Text('Aleatorio',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Todas las preguntas mezcladas',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF7A7770))),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pop(ctx, 'aleatorio'),
            ),
          ],
        ),
      ),
    );

    if (modo == null || !mounted) return;
    await _estudiarMultiMazo(modo);
  }

  Future<void> _estudiarMultiMazo(String modo) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
            color: Color(0xFFE85D3A)),
      ),
    );

    try {
      final mazosSeleccionados = _misDecks
          .where((d) => _seleccionados.contains(d['id']))
          .toList();

      // Cargar todos los mazos en paralelo
      final mazosCompletos = await Future.wait(
        mazosSeleccionados.map(
            (d) => FirestoreService().obtenerMazoCompleto(d)),
      );

      // Combinar preguntas
      final todasPreguntas = <Pregunta>[];
      for (final mazo in mazosCompletos) {
        if (mazo != null) {
          todasPreguntas.addAll(mazo.preguntas);
        }
      }

      if (modo == 'aleatorio') {
        todasPreguntas.shuffle();
      }

      if (!mounted) return;
      Navigator.pop(context); // cerrar loading

      if (todasPreguntas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Los mazos seleccionados no tienen preguntas')),
        );
        return;
      }

      final mazoTemporal = Mazo(
        titulo:
            'Estudio combinado · ${_seleccionados.length} mazos',
        categoria: 'Multi-mazo',
        preguntas: todasPreguntas,
      );

      _cancelarSeleccion();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudyScreen(
            mazo: mazoTemporal,
            esPremium: _esPremium,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar mazos: $e')),
        );
      }
    }
  }

  Future<void> _estudioRapido() async {
    if (_misDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea tu primer mazo')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Verificar límite de sesiones
    if (!_esPremium && uid != null) {
      final puede = await FirestoreService().puedeEstudiar(uid);
      if (!mounted) return;
      if (!puede) {
        await _mostrarLimiteDiario(uid);
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child:
            CircularProgressIndicator(color: Color(0xFFE85D3A)),
      ),
    );

    try {
      final mazosCompletos = await Future.wait(
        _misDecks.map(
            (d) => FirestoreService().obtenerMazoCompleto(d)),
      );

      final todasPreguntas = <Pregunta>[];
      for (final mazo in mazosCompletos) {
        if (mazo != null) todasPreguntas.addAll(mazo.preguntas);
      }

      todasPreguntas.shuffle();
      final seleccionadas = todasPreguntas.take(5).toList();

      if (!mounted) return;
      Navigator.pop(context); // cerrar loading

      if (seleccionadas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Tus mazos no tienen preguntas aún')),
        );
        return;
      }

      if (uid != null && !_esPremium) {
        await FirestoreService().registrarSesion(uid);
        if (!mounted) return;
      }

      final mazoRapido = Mazo(
        titulo: '⚡ Estudio rápido',
        categoria: 'Rápido',
        preguntas: seleccionadas,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudyScreen(
            mazo: mazoRapido,
            esPremium: _esPremium,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _mostrarLimiteDiario(String uid) async {
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
                    content: Text('Anuncios próximamente')),
              );
            },
            child: const Text('Ver anuncio (+3 sesiones)'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (mounted) {
                final activo =
                    await mostrarDialogoPremium(context);
                if (activo) _cargarDecks();
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

  Future<void> _abrirDuelos() async {
    if (!_esPremium) {
      await mostrarDialogoPremium(context);
      return;
    }
    await mostrarDuelosBottomSheet(
      context,
      misDecks: _misDecks,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDuelos,
        backgroundColor: const Color(0xFF0F0E0C),
        foregroundColor: Colors.white,
        tooltip: 'Duelo',
        child: const Icon(Icons.sports_esports),
      ),
      // Barra inferior cuando hay selección activa
      bottomSheet: (_modoSeleccion && _seleccionados.length >= 2)
          ? Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _mostrarDialogoModoEstudio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0E0C),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Estudiar ${_seleccionados.length} mazos',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarDecks,
          color: const Color(0xFFE85D3A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 0,
              bottom: (_modoSeleccion && _seleccionados.length >= 2)
                  ? 100
                  : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Header: saludo + ajustes
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hola, ${FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'Estudiante'} 👋',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7A7770)),
                    ),
                    IconButton(
                      onPressed: () => mostrarConfiguracion(
                        context,
                        esPremium: _esPremium,
                      ),
                      icon: const Icon(Icons.settings_outlined,
                          size: 22,
                          color: Color(0xFF7A7770)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
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
                // Stats
                Row(
                  children: [
                    _StatCard(
                        label: 'Mazos',
                        value: '${_misDecks.length}',
                        sub: _esPremium
                            ? 'ilimitados'
                            : 'de 3 gratis',
                        color: const Color(0xFFE85D3A)),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'K-Score',
                        value: _kScorePromedio > 0
                            ? '⚡${_kScorePromedio.round()}'
                            : '—',
                        sub: 'eficiencia',
                        color: const Color(0xFFF5A623)),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Racha',
                        value: '0',
                        sub: 'días',
                        color: const Color(0xFFE85D3A)),
                  ],
                ),
                const SizedBox(height: 16),
                // Card de estudio rápido
                GestureDetector(
                  onTap: _estudioRapido,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0F0E0C),
                          Color(0xFF2A2825),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: const [
                              Text('⚡ Estudio rápido · 5 preguntas',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              SizedBox(height: 4),
                              Text(
                                  'Preguntas aleatorias de todos tus mazos',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFADABA6))),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Título "Creados por mí" con botón de selección
                Row(
                  children: [
                    Expanded(
                      child: _modoSeleccion
                          ? Row(
                              children: [
                                Text(
                                  'Selecciona mazos (${_seleccionados.length})',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.w700),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _cancelarSeleccion,
                                  child: const Text('Cancelar',
                                      style: TextStyle(
                                          color:
                                              Color(0xFFE85D3A))),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Creados por mí',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight:
                                                FontWeight.w700)),
                                    Text('Tus bancos de preguntas',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(
                                                0xFF7A7770))),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _activarModoSeleccion,
                                  icon: const Icon(
                                      Icons.checklist_rounded,
                                      color: Color(0xFF7A7770),
                                      size: 22),
                                  tooltip: 'Seleccionar mazos',
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
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
                          esPremium: _esPremium,
                          onEliminar: () =>
                              _eliminarMazo(deck['id'] ?? ''),
                          modoSeleccion: _modoSeleccion,
                          seleccionado: _seleccionados
                              .contains(deck['id'] ?? ''),
                          onToggleSeleccion: () =>
                              _toggleSeleccion(deck['id'] ?? ''),
                        ),
                      )),
                const SizedBox(height: 16),
                // Footer premium
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
                                  value:
                                      (_misDecks.length / 3)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CARD DE MAZO
// ─────────────────────────────────────────────────
class _FirestoreDeckCard extends StatelessWidget {
  final Map<String, dynamic> deck;
  final VoidCallback onEliminar;
  final bool esPremium;
  final bool modoSeleccion;
  final bool seleccionado;
  final VoidCallback? onToggleSeleccion;

  const _FirestoreDeckCard({
    required this.deck,
    required this.onEliminar,
    required this.esPremium,
    this.modoSeleccion = false,
    this.seleccionado = false,
    this.onToggleSeleccion,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: modoSeleccion ? onToggleSeleccion : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: seleccionado
              ? const Color(0xFFFFF8F6)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado
                ? const Color(0xFFE85D3A)
                : const Color(0xFFE4E0D6),
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (modoSeleccion) ...[
                  Checkbox(
                    value: seleccionado,
                    onChanged: (_) => onToggleSeleccion?.call(),
                    activeColor: const Color(0xFFE85D3A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 4),
                ],
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
                const Spacer(),
                if (!modoSeleccion)
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
            if (!modoSeleccion) ...[
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
                        padding:
                            const EdgeInsets.symmetric(
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
                      onPressed: () =>
                          _estudiarDeck(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0F0E0C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 8),
                      ),
                      child: const Text('Estudiar',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _estudiarDeck(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (!esPremium && uid != null) {
      final puede =
          await FirestoreService().puedeEstudiar(uid);
      if (!puede) {
        if (context.mounted) {
          await _mostrarLimiteDiario(context, uid);
        }
        return;
      }
    }

    final mazo =
        await FirestoreService().obtenerMazoCompleto(deck);
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

// ─────────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────────
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
                    fontSize: 22,
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
