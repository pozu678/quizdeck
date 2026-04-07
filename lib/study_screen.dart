import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'widgets/paywall_sheet.dart';

// ═══════════════════════════════════════
// MODELO DE DATOS
// ═══════════════════════════════════════
class Opcion {
  final String letra;
  final String texto;
  final String explicacion;
  final bool esCorrecta;

  const Opcion({
    required this.letra,
    required this.texto,
    required this.explicacion,
    required this.esCorrecta,
  });
}

class Pregunta {
  final String enunciado;
  final List<Opcion> opciones;

  const Pregunta({
    required this.enunciado,
    required this.opciones,
  });
}

class Mazo {
  final String titulo;
  final String categoria;
  final List<Pregunta> preguntas;
  final bool esAleatorio;

  const Mazo({
    required this.titulo,
    required this.categoria,
    required this.preguntas,
    this.esAleatorio = false,
  });
}

// ═══════════════════════════════════════
// DATOS DE EJEMPLO
// ═══════════════════════════════════════
final mazoEjemplo = Mazo(
  titulo: 'Bioquímica — Metabolismo celular',
  categoria: 'Medicina',
  preguntas: [
    Pregunta(
      enunciado:
          '¿Cuál es el producto final neto de la glucólisis por cada molécula de glucosa?',
      opciones: [
        Opcion(
          letra: 'A',
          texto: '1 ATP y 1 NADH',
          explicacion:
              'Solo la primera etapa. El neto de ambas fases es mayor.',
          esCorrecta: false,
        ),
        Opcion(
          letra: 'B',
          texto: '2 ATP y 2 NADH',
          explicacion:
              'Correcto. La glucólisis produce un neto de 2 ATP y 2 NADH por molécula de glucosa.',
          esCorrecta: true,
        ),
        Opcion(
          letra: 'C',
          texto: '4 ATP y 2 FADH₂',
          explicacion:
              '4 ATP es la producción bruta. El FADH₂ es producto del ciclo de Krebs.',
          esCorrecta: false,
        ),
        Opcion(
          letra: 'D',
          texto: '36 ATP y 2 NADH',
          explicacion:
              '36-38 ATP es el rendimiento total de la respiración celular completa.',
          esCorrecta: false,
        ),
      ],
    ),
    Pregunta(
      enunciado:
          '¿En qué compartimento celular ocurre el ciclo de Krebs?',
      opciones: [
        Opcion(
          letra: 'A',
          texto: 'Citoplasma',
          explicacion:
              'El citoplasma es la sede de la glucólisis, no del ciclo de Krebs.',
          esCorrecta: false,
        ),
        Opcion(
          letra: 'B',
          texto: 'Núcleo celular',
          explicacion:
              'El núcleo alberga el material genético y no participa en el metabolismo energético.',
          esCorrecta: false,
        ),
        Opcion(
          letra: 'C',
          texto: 'Matriz mitocondrial',
          explicacion:
              'Correcto. El ciclo de Krebs ocurre en la matriz mitocondrial.',
          esCorrecta: true,
        ),
        Opcion(
          letra: 'D',
          texto: 'Membrana plasmática',
          explicacion:
              'La cadena respiratoria está en la membrana interna mitocondrial, no el ciclo de Krebs.',
          esCorrecta: false,
        ),
      ],
    ),
  ],
);

// ═══════════════════════════════════════
// PANTALLA DE ESTUDIO
// ═══════════════════════════════════════
class StudyScreen extends StatefulWidget {
  final Mazo mazo;
  final bool esPremium;
  // deckId opcional para guardar progreso (null = mazo combinado/temporal)
  final String? deckId;

  const StudyScreen({
    super.key,
    required this.mazo,
    this.esPremium = false,
    this.deckId,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _preguntaActual = 0;
  int? _opcionSeleccionada;
  bool _respondida = false;
  int _correctas = 0;
  bool _terminado = false;

  // Timer por pregunta para calcular K-Score
  final Stopwatch _cronometro = Stopwatch();
  final List<int> _tiemposPorPregunta = []; // ms por respuesta

  @override
  void initState() {
    super.initState();
    _cronometro.start();
  }

  @override
  void dispose() {
    _cronometro.stop();
    super.dispose();
  }

  void _seleccionarOpcion(int idx) {
    if (_respondida) return;
    _cronometro.stop();
    final tiempoMs = _cronometro.elapsedMilliseconds;
    _tiemposPorPregunta.add(tiempoMs);

    final esCorrecta =
        widget.mazo.preguntas[_preguntaActual].opciones[idx].esCorrecta;
    setState(() {
      _opcionSeleccionada = idx;
      _respondida = true;
      if (esCorrecta) _correctas++;
    });
  }

  void _siguiente() {
    if (_preguntaActual < widget.mazo.preguntas.length - 1) {
      _cronometro
        ..reset()
        ..start();
      setState(() {
        _preguntaActual++;
        _opcionSeleccionada = null;
        _respondida = false;
      });
    } else {
      setState(() => _terminado = true);
      _guardarProgreso();
    }
  }

  /// Calcula el K-Score usando la fórmula de eficiencia.
  double _calcularKScore() {
    final total = widget.mazo.preguntas.length;
    if (total == 0) return 0;

    const tiempoBase = 15000; // 15 segundos en ms
    final tiempoUsuario = _tiemposPorPregunta.isEmpty
        ? tiempoBase
        : _tiemposPorPregunta.reduce((a, b) => a + b) ~/
            _tiemposPorPregunta.length;

    final velocidadBonus =
        (tiempoBase - tiempoUsuario).clamp(0, tiempoBase) /
            tiempoBase *
            0.3;

    return (_correctas / total * 100) * (1 + velocidadBonus);
  }

  int _tiempoPromedioMs() {
    if (_tiemposPorPregunta.isEmpty) return 0;
    return _tiemposPorPregunta.reduce((a, b) => a + b) ~/
        _tiemposPorPregunta.length;
  }

  Future<void> _guardarProgreso() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final deckId = widget.deckId;
    if (uid == null || deckId == null) return;
    final total = widget.mazo.preguntas.length;
    if (total == 0) return;
    await FirestoreService().guardarProgreso(
      uid: uid,
      deckId: deckId,
      correctas: _correctas,
      total: total,
      kScore: _calcularKScore(),
      tiempoPromedio: _tiempoPromedioMs(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_terminado) return _buildResultados();

    final pregunta = widget.mazo.preguntas[_preguntaActual];
    final total = widget.mazo.preguntas.length;
    final progreso = (_preguntaActual + 1) / total;

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
        title: Column(
          children: [
            Text(
              'Pregunta ${_preguntaActual + 1} de $total',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7A7770),
                fontWeight: FontWeight.w400,
              ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDE6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Práctica',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A3832))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de pregunta
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE4E0D6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pregunta',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A7770),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Text(
                    pregunta.enunciado,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: Color(0xFF0F0E0C)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Opciones
            ...List.generate(pregunta.opciones.length, (i) {
              final opcion = pregunta.opciones[i];
              return _buildOpcion(opcion, i);
            }),
            const SizedBox(height: 20),
            // Botón siguiente
            if (_respondida)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _siguiente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0E0C),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _preguntaActual <
                            widget.mazo.preguntas.length - 1
                        ? 'Siguiente pregunta →'
                        : 'Ver resultados →',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcion(Opcion opcion, int idx) {
    Color borderColor = const Color(0xFFE4E0D6);
    Color bgColor = const Color(0xFFFAF8F4);
    Color letraColor = const Color(0xFF3A3832);
    Color letraBg = const Color(0xFFE4E0D6);

    if (_respondida) {
      if (opcion.esCorrecta) {
        borderColor = const Color(0xFF2D9E6B);
        bgColor = const Color(0xFFEAF7F0);
        letraColor = Colors.white;
        letraBg = const Color(0xFF2D9E6B);
      } else if (idx == _opcionSeleccionada) {
        borderColor = const Color(0xFFD94444);
        bgColor = const Color(0xFFFDECEA);
        letraColor = Colors.white;
        letraBg = const Color(0xFFD94444);
      } else {
        bgColor = const Color(0xFFFAF8F4);
        borderColor = const Color(0xFFE4E0D6);
        letraColor = const Color(0xFF7A7770);
        letraBg = const Color(0xFFE4E0D6);
      }
    }

    return GestureDetector(
      onTap: () => _seleccionarOpcion(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
                            fontWeight: FontWeight.w700,
                            color: letraColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(opcion.texto,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF0F0E0C))),
                ),
                if (_respondida)
                  Icon(
                    opcion.esCorrecta
                        ? Icons.check_circle
                        : idx == _opcionSeleccionada
                            ? Icons.cancel
                            : null,
                    color: opcion.esCorrecta
                        ? const Color(0xFF2D9E6B)
                        : const Color(0xFFD94444),
                    size: 20,
                  ),
              ],
            ),
            if (_respondida)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  margin: const EdgeInsets.only(top: 12, left: 40),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: opcion.esCorrecta
                            ? const Color(0xFF2D9E6B)
                            : idx == _opcionSeleccionada
                                ? const Color(0xFFD94444)
                                : const Color(0xFFE4E0D6),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(opcion.explicacion,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF3A3832),
                          height: 1.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultados() {
    final total = widget.mazo.preguntas.length;
    final pct = (_correctas / total * 100).round();
    final kScore = _calcularKScore();
    final color = pct >= 70
        ? const Color(0xFF2D9E6B)
        : pct >= 40
            ? const Color(0xFFF5A623)
            : const Color(0xFFE85D3A);
    final mensaje = pct >= 80
        ? '¡Excelente dominio!'
        : pct >= 60
            ? 'Buen trabajo'
            : 'Sigue practicando';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Círculo de porcentaje
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 6),
                ),
                child: Center(
                  child: Text('$pct%',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ),
              ),
              const SizedBox(height: 16),
              Text(mensaje,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(widget.mazo.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF7A7770))),
              const SizedBox(height: 8),
              // K-Score
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E6),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFFF5A623)),
                ),
                child: Text(
                  '⚡ K-Score: ${kScore.round()}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB87A00)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _ResultStat(
                      label: 'Correctas',
                      value: '$_correctas',
                      color: const Color(0xFF2D9E6B)),
                  _ResultStat(
                      label: 'Incorrectas',
                      value: '${total - _correctas}',
                      color: const Color(0xFFE85D3A)),
                  _ResultStat(
                      label: 'Total',
                      value: '$total',
                      color: const Color(0xFF0F0E0C)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _preguntaActual = 0;
                      _opcionSeleccionada = null;
                      _respondida = false;
                      _correctas = 0;
                      _terminado = false;
                      _tiemposPorPregunta.clear();
                      _cronometro
                        ..reset()
                        ..start();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0E0C),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Repetir mazo',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFFE4E0D6)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Volver a mis mazos',
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0F0E0C))),
                ),
              ),
              // Banner premium (solo para usuarios gratuitos)
              if (!widget.esPremium) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E6),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFF5A623)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '¿Quieres estudiar sin límites?',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3A3832)),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            mostrarDialogoPremium(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        child: const Text('Hazte Premium →',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE85D3A))),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ResultStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDE6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF7A7770))),
          ],
        ),
      ),
    );
  }
}
