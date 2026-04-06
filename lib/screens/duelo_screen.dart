import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../firestore_service.dart';
import '../study_screen.dart';

// ═══════════════════════════════════════════════════════
// BOTTOM SHEET DE INICIO DE DUELOS
// ═══════════════════════════════════════════════════════
Future<void> mostrarDuelosBottomSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> misDecks,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _DueloInicioSheet(misDecks: misDecks),
  );
}

class _DueloInicioSheet extends StatefulWidget {
  final List<Map<String, dynamic>> misDecks;
  const _DueloInicioSheet({required this.misDecks});

  @override
  State<_DueloInicioSheet> createState() =>
      _DueloInicioSheetState();
}

class _DueloInicioSheetState extends State<_DueloInicioSheet> {
  final _codigoCtrl = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearDuelo() async {
    if (widget.misDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Necesitas al menos un mazo para crear un duelo')),
      );
      return;
    }

    // Seleccionar mazo
    final deckSeleccionado = await showModalBottomSheet<
        Map<String, dynamic>>(
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
            const SizedBox(height: 16),
            const Text('Elige un mazo para el duelo',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...widget.misDecks.map(
              (d) => ListTile(
                title: Text(d['titulo'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(d['categoria'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFF7A7770))),
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.pop(ctx, d),
              ),
            ),
          ],
        ),
      ),
    );

    if (deckSeleccionado == null || !mounted) return;

    setState(() => _cargando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final nombre =
          FirebaseAuth.instance.currentUser?.displayName ??
              'Jugador';
      final deckId = deckSeleccionado['id'] as String;

      // Obtener preguntas para el duelo
      final preguntasData = await FirestoreService()
          .seleccionarPreguntasParaDuelo(
              deckId: deckId, cantidad: 10);

      final codigo = await FirestoreService().crearDuelo(
        uid: uid,
        nombre: nombre,
        deckId: deckId,
        deckTitulo: deckSeleccionado['titulo'] ?? '',
        preguntas: preguntasData,
      );

      // Obtener el dueloId buscando por código
      final dueloData =
          await FirestoreService().buscarDueloPorCodigo(codigo);
      if (dueloData == null || !mounted) return;

      Navigator.pop(context); // cerrar sheet principal
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DueloEsperaScreen(
            dueloId: dueloData['id'] as String,
            codigo: codigo,
            esCreador: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _cargando = false);
  }

  Future<void> _unirseDuelo() async {
    final codigo = _codigoCtrl.text.trim().toUpperCase();
    if (codigo.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El código debe tener 6 caracteres')),
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      final dueloData =
          await FirestoreService().buscarDueloPorCodigo(codigo);
      if (dueloData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'No se encontró el duelo o ya está en curso')),
          );
        }
        setState(() => _cargando = false);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final nombre =
          FirebaseAuth.instance.currentUser?.displayName ??
              'Retador';
      final dueloId = dueloData['id'] as String;

      await FirestoreService().unirseDuelo(
        dueloId: dueloId,
        uid: uid,
        nombre: nombre,
      );

      if (!mounted) return;
      Navigator.pop(context); // cerrar sheet principal
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DueloEsperaScreen(
            dueloId: dueloId,
            codigo: codigo,
            esCreador: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text('Duelos 1v1',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Reta a tus amigos en tiempo real',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF7A7770))),
          const SizedBox(height: 24),
          // Crear duelo
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cargando ? null : _crearDuelo,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear duelo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F0E0C),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE4E0D6))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o únete',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7770))),
              ),
              Expanded(child: Divider(color: Color(0xFFE4E0D6))),
            ],
          ),
          const SizedBox(height: 16),
          // Código de duelo
          TextField(
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Código de 6 caracteres',
              hintStyle:
                  const TextStyle(color: Color(0xFF7A7770)),
              filled: true,
              fillColor: const Color(0xFFFAF8F4),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE4E0D6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE4E0D6)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cargando ? null : _unirseDuelo,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Color(0xFFE85D3A)),
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE85D3A)))
                  : const Text('Unirse al duelo',
                      style: TextStyle(
                          color: Color(0xFFE85D3A),
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PANTALLA DE ESPERA
// ═══════════════════════════════════════════════════════
class DueloEsperaScreen extends StatefulWidget {
  final String dueloId;
  final String codigo;
  final bool esCreador;

  const DueloEsperaScreen({
    super.key,
    required this.dueloId,
    required this.codigo,
    required this.esCreador,
  });

  @override
  State<DueloEsperaScreen> createState() =>
      _DueloEsperaScreenState();
}

class _DueloEsperaScreenState extends State<DueloEsperaScreen> {
  int _countdown = 0;
  bool _iniciando = false;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _iniciarCountdown() {
    setState(() {
      _iniciando = true;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _navegarAlJuego();
      }
    });
  }

  void _navegarAlJuego() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DueloJuegoScreen(
          dueloId: widget.dueloId,
          esCreador: widget.esCreador,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(0xFF0F0E0C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Duelo',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder(
        stream:
            FirestoreService().streamDuelo(widget.dueloId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFE85D3A)),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) return const SizedBox();

          final estado = data['estado'] as String? ?? '';
          final retadorNombre =
              data['retadorNombre'] as String?;

          // Si el duelo ya está en_curso y no hemos iniciado countdown
          if (estado == 'en_curso' && !_iniciando) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) {
              if (mounted) _iniciarCountdown();
            });
          }

          if (_iniciando) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE85D3A)),
                  ),
                  const SizedBox(height: 16),
                  const Text('¡Prepárate!',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0E0C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.sports_esports,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Duelo creado',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  data['deckTitulo'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7A7770)),
                ),
                const SizedBox(height: 32),
                // Código grande
                Container(
                  padding:
                      const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE4E0D6)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                          'Código para compartir',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A7770))),
                      const SizedBox(height: 12),
                      Text(
                        widget.codigo,
                        style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: Color(0xFF0F0E0C)),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          Share.share(
                            '¡Te reto en QuizDeck! Usa el código ${widget.codigo} para unirte al duelo.',
                            subject: 'Duelo QuizDeck',
                          );
                        },
                        icon: const Icon(Icons.share,
                            size: 16),
                        label: const Text(
                            'Compartir código'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (retadorNombre != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F0),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF2D9E6B),
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$retadorNombre se unió al duelo',
                          style: const TextStyle(
                              color: Color(0xFF2D9E6B),
                              fontWeight:
                                  FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7A7770),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                          'Esperando rival…',
                          style: TextStyle(
                              color: Color(0xFF7A7770))),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PANTALLA DE JUEGO
// ═══════════════════════════════════════════════════════
class DueloJuegoScreen extends StatefulWidget {
  final String dueloId;
  final bool esCreador;

  const DueloJuegoScreen({
    super.key,
    required this.dueloId,
    required this.esCreador,
  });

  @override
  State<DueloJuegoScreen> createState() =>
      _DueloJuegoScreenState();
}

class _DueloJuegoScreenState extends State<DueloJuegoScreen> {
  List<Map<String, dynamic>> _preguntasData = [];
  int _preguntaActual = 0;
  int? _opcionSeleccionada;
  bool _respondida = false;
  bool _cargando = true;
  final Stopwatch _cronometro = Stopwatch();

  @override
  void initState() {
    super.initState();
    _cargarPreguntas();
  }

  @override
  void dispose() {
    _cronometro.stop();
    super.dispose();
  }

  Future<void> _cargarPreguntas() async {
    final preguntas = await FirestoreService()
        .obtenerPreguntasDuelo(widget.dueloId);
    setState(() {
      _preguntasData = preguntas;
      _cargando = false;
    });
    _cronometro.start();
  }

  List<Opcion> _opcionesDeData(
      Map<String, dynamic> preguntaData) {
    final opciones = preguntaData['opciones'] as List? ?? [];
    return opciones
        .map((o) => Opcion(
              letra: o['letra'] ?? '',
              texto: o['texto'] ?? '',
              explicacion: o['explicacion'] ?? '',
              esCorrecta: o['esCorrecta'] ?? false,
            ))
        .toList();
  }

  Future<void> _seleccionarOpcion(int idx) async {
    if (_respondida) return;
    _cronometro.stop();
    final tiempoMs = _cronometro.elapsedMilliseconds;
    final opciones = _opcionesDeData(
        _preguntasData[_preguntaActual]);
    final correcta = opciones[idx].esCorrecta;

    setState(() {
      _opcionSeleccionada = idx;
      _respondida = true;
    });

    // Guardar respuesta en Firestore
    await FirestoreService().guardarRespuestaDuelo(
      dueloId: widget.dueloId,
      esCreador: widget.esCreador,
      respuesta: {
        'preguntaIdx': _preguntaActual,
        'respuestaIdx': idx,
        'correcta': correcta,
        'tiempoMs': tiempoMs,
      },
    );

    // Esperar 1 segundo y pasar a siguiente
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    if (_preguntaActual < _preguntasData.length - 1) {
      _cronometro
        ..reset()
        ..start();
      setState(() {
        _preguntaActual++;
        _opcionSeleccionada = null;
        _respondida = false;
      });
    } else {
      _esperarResultados();
    }
  }

  Future<void> _esperarResultados() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DueloResultadoScreen(
          dueloId: widget.dueloId,
          esCreador: widget.esCreador,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF8F4),
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFFE85D3A)),
        ),
      );
    }

    if (_preguntasData.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No hay preguntas')),
      );
    }

    final preguntaData = _preguntasData[_preguntaActual];
    final opciones = _opcionesDeData(preguntaData);
    final total = _preguntasData.length;
    final progreso = (_preguntaActual + 1) / total;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F4),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            Text(
              'Pregunta ${_preguntaActual + 1} de $total',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF7A7770)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progreso,
                backgroundColor: const Color(0xFFE4E0D6),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE85D3A)),
                minHeight: 5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE85D3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('⚔️ Duelo',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tarjeta pregunta
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFE4E0D6)),
              ),
              child: Text(
                preguntaData['enunciado'] ?? '',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: Color(0xFF0F0E0C)),
              ),
            ),
            const SizedBox(height: 16),
            // Opciones
            ...List.generate(opciones.length, (i) {
              final opcion = opciones[i];
              Color borderColor = const Color(0xFFE4E0D6);
              Color bgColor = const Color(0xFFFAF8F4);
              Color letraBg = const Color(0xFFE4E0D6);
              Color letraColor = const Color(0xFF3A3832);

              if (_respondida) {
                if (opcion.esCorrecta) {
                  borderColor = const Color(0xFF2D9E6B);
                  bgColor = const Color(0xFFEAF7F0);
                  letraBg = const Color(0xFF2D9E6B);
                  letraColor = Colors.white;
                } else if (i == _opcionSeleccionada) {
                  borderColor = const Color(0xFFD94444);
                  bgColor = const Color(0xFFFDECEA);
                  letraBg = const Color(0xFFD94444);
                  letraColor = Colors.white;
                }
              }

              return GestureDetector(
                onTap: () => _seleccionarOpcion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: letraBg,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(opcion.letra,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: letraColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opcion.texto,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F0E0C))),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PANTALLA DE RESULTADOS DEL DUELO
// ═══════════════════════════════════════════════════════
class DueloResultadoScreen extends StatelessWidget {
  final String dueloId;
  final bool esCreador;

  const DueloResultadoScreen({
    super.key,
    required this.dueloId,
    required this.esCreador,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      body: StreamBuilder(
        stream: FirestoreService().streamDuelo(dueloId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFE85D3A)),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) return const SizedBox();

          final respuestasCreador =
              (data['respuestasCreador'] as List?) ?? [];
          final respuestasRetador =
              (data['respuestasRetador'] as List?) ?? [];
          final total =
              (data['totalPreguntas'] as int?) ?? 10;
          final creadorNombre =
              data['creadorNombre'] as String? ?? 'Creador';
          final retadorNombre =
              data['retadorNombre'] as String? ?? 'Retador';

          // Esperar que ambos terminen
          final ambosTerminaron =
              respuestasCreador.length >= total &&
                  respuestasRetador.length >= total;

          if (!ambosTerminaron) {
            final miProgreso = esCreador
                ? respuestasCreador.length
                : respuestasRetador.length;
            final rivalProgreso = esCreador
                ? respuestasRetador.length
                : respuestasCreador.length;

            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_top,
                          size: 48,
                          color: Color(0xFF7A7770)),
                      const SizedBox(height: 16),
                      const Text('¡Tú ya terminaste!',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Esperando al rival… ($rivalProgreso/$total)',
                        style: const TextStyle(
                            color: Color(0xFF7A7770)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu avance: $miProgreso/$total',
                        style: const TextStyle(
                            color: Color(0xFF7A7770)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Calcular resultados
          final correctasCreador = respuestasCreador
              .where((r) => r['correcta'] == true)
              .length;
          final correctasRetador = respuestasRetador
              .where((r) => r['correcta'] == true)
              .length;

          final tiempoCreador = respuestasCreador.isEmpty
              ? 0
              : respuestasCreador
                  .map((r) => (r['tiempoMs'] as int?) ?? 0)
                  .reduce((a, b) => a + b);
          final tiempoRetador = respuestasRetador.isEmpty
              ? 0
              : respuestasRetador
                  .map((r) => (r['tiempoMs'] as int?) ?? 0)
                  .reduce((a, b) => a + b);

          // Determinar ganador
          String? ganadorNombre;
          if (correctasCreador > correctasRetador) {
            ganadorNombre = creadorNombre;
          } else if (correctasRetador > correctasCreador) {
            ganadorNombre = retadorNombre;
          } else {
            // Empate: gana el más rápido
            ganadorNombre = tiempoCreador <= tiempoRetador
                ? creadorNombre
                : retadorNombre;
          }

          final miNombre = esCreador
              ? creadorNombre
              : retadorNombre;
          final yoGane = ganadorNombre == miNombre;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    yoGane ? '🏆 ¡Ganaste!' : 'Buen intento',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: yoGane
                            ? const Color(0xFFF5A623)
                            : const Color(0xFF0F0E0C)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    yoGane
                        ? '¡Dominas este mazo!'
                        : '$ganadorNombre ganó el duelo',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A7770)),
                  ),
                  const SizedBox(height: 32),
                  // Comparación lado a lado
                  Row(
                    children: [
                      _DueloPuntuacion(
                        nombre: creadorNombre,
                        correctas: correctasCreador,
                        tiempoMs: tiempoCreador,
                        esGanador:
                            ganadorNombre == creadorNombre,
                        esToYo: esCreador,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8),
                        child: Column(
                          children: const [
                            Text('vs',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        Color(0xFF7A7770))),
                          ],
                        ),
                      ),
                      _DueloPuntuacion(
                        nombre: retadorNombre,
                        correctas: correctasRetador,
                        tiempoMs: tiempoRetador,
                        esGanador:
                            ganadorNombre == retadorNombre,
                        esToYo: !esCreador,
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.popUntil(
                              context, (r) => r.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0F0E0C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                      child: const Text('Volver',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DueloPuntuacion extends StatelessWidget {
  final String nombre;
  final int correctas;
  final int tiempoMs;
  final bool esGanador;
  final bool esToYo;

  const _DueloPuntuacion({
    required this.nombre,
    required this.correctas,
    required this.tiempoMs,
    required this.esGanador,
    required this.esToYo,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esGanador
              ? const Color(0xFFFFF4E6)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: esGanador
                ? const Color(0xFFF5A623)
                : const Color(0xFFE4E0D6),
            width: esGanador ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (esGanador)
              const Text('🏆',
                  style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              nombre + (esToYo ? ' (tú)' : ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '$correctas',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: esGanador
                      ? const Color(0xFFF5A623)
                      : const Color(0xFF0F0E0C)),
            ),
            const Text('correctas',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7A7770))),
            const SizedBox(height: 4),
            Text(
              '${(tiempoMs / 1000).toStringAsFixed(1)}s',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A7770)),
            ),
          ],
        ),
      ),
    );
  }
}
