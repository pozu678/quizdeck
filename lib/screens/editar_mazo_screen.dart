import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_service.dart';
import '../study_screen.dart';
import '../widgets/paywall_sheet.dart';
import '../models/mazo_local.dart';
import '../services/local_storage_service.dart';

class EditarMazoScreen extends StatefulWidget {
  final Map<String, dynamic> deck;
  final bool esPremium;
  final bool esLocal;
  final MazoLocal? mazoLocal;

  const EditarMazoScreen({
    super.key,
    required this.deck,
    required this.esPremium,
    required this.esLocal,
    this.mazoLocal,
  });

  @override
  State<EditarMazoScreen> createState() => _EditarMazoScreenState();
}

class _EditarMazoScreenState extends State<EditarMazoScreen> {
  final _tituloCtrl = TextEditingController();
  String _categoria = 'Medicina';
  bool _esPublico = false;
  bool _esAleatorio = false;
  bool _cargando = true;
  bool _guardando = false;

  final List<Map<String, dynamic>> _preguntas = [];

  final List<String> _categorias = [
    'Medicina', 'Ciencias', 'Derecho',
    'Historia', 'Matemática', 'Otro'
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    _tituloCtrl.text = widget.deck['titulo'] ?? '';
    _categoria = widget.deck['categoria'] ?? 'Medicina';
    _esPublico = widget.deck['esPublico'] == true;
    _esAleatorio = widget.deck['esAleatorio'] == true;

    if (widget.esLocal && widget.mazoLocal != null) {
      _esAleatorio = widget.mazoLocal!.esAleatorio;
      _poblarPreguntas(widget.mazoLocal!.preguntas
          .map((p) => Pregunta(
                enunciado: p.enunciado,
                opciones: p.opciones
                    .map((o) => Opcion(
                          letra: o.letra,
                          texto: o.texto,
                          explicacion: o.explicacion,
                          esCorrecta: o.esCorrecta,
                        ))
                    .toList(),
              ))
          .toList());
    } else {
      // Cargar desde Firestore
      final mazo = await FirestoreService().obtenerMazoCompleto(widget.deck);
      if (mazo != null) {
        _esAleatorio = widget.deck['esAleatorio'] == true;
        _poblarPreguntas(mazo.preguntas);
      }
    }

    if (mounted) setState(() => _cargando = false);
  }

  void _poblarPreguntas(List<Pregunta> preguntas) {
    for (final p in preguntas) {
      final opciones = p.opciones.asMap().entries.map((e) {
        return {
          'texto': TextEditingController(text: e.value.texto),
          'explicacion': TextEditingController(text: e.value.explicacion),
          'esCorrecta': e.value.esCorrecta,
        };
      }).toList();
      _preguntas.add({
        'enunciado': TextEditingController(text: p.enunciado),
        'opciones': opciones,
      });
    }
  }

  void _agregarPregunta() {
    setState(() {
      _preguntas.add({
        'enunciado': TextEditingController(),
        'opciones': List.generate(4, (i) => {
          'texto': TextEditingController(),
          'explicacion': TextEditingController(),
          'esCorrecta': i == 0,
        }),
      });
    });
  }

  void _eliminarPregunta(int idx) {
    setState(() => _preguntas.removeAt(idx));
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un título para el mazo')),
      );
      return;
    }
    if (_preguntas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una pregunta')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final preguntas = _preguntas.map((p) {
        final opciones = (p['opciones'] as List).asMap().entries.map((e) {
          final o = e.value as Map<String, dynamic>;
          return Opcion(
            letra: ['A', 'B', 'C', 'D'][e.key],
            texto: (o['texto'] as TextEditingController).text,
            explicacion: (o['explicacion'] as TextEditingController).text,
            esCorrecta: o['esCorrecta'] as bool,
          );
        }).toList();
        return Pregunta(
          enunciado: (p['enunciado'] as TextEditingController).text,
          opciones: opciones,
        );
      }).toList();

      final mazo = Mazo(
        titulo: _tituloCtrl.text.trim(),
        categoria: _categoria,
        preguntas: preguntas,
        esAleatorio: _esAleatorio,
      );

      if (widget.esLocal) {
        final local = widget.mazoLocal!;
        final actualizado = MazoLocal(
          id: local.id,
          titulo: mazo.titulo,
          categoria: mazo.categoria,
          esPublico: false,
          esAleatorio: _esAleatorio,
          preguntas: preguntas
              .map((p) => PreguntaLocal(
                    enunciado: p.enunciado,
                    opciones: p.opciones
                        .map((o) => OpcionLocal(
                              letra: o.letra,
                              texto: o.texto,
                              explicacion: o.explicacion,
                              esCorrecta: o.esCorrecta,
                            ))
                        .toList(),
                  ))
              .toList(),
          sincronizado: local.sincronizado,
          firebaseId: local.firebaseId,
          creadoEn: local.creadoEn,
        );
        await LocalStorageService().updateMazo(actualizado);
      } else {
        // Premium: verificar publicación
        final deckId = widget.deck['id'] as String;
        if (_esPublico && preguntas.length < 10) {
          if (!mounted) return;
          setState(() => _guardando = false);
          final accion = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Pocas preguntas para publicar'),
              content: Text(
                'Para publicar necesitas al menos 10 preguntas. '
                'Tu mazo tiene ${preguntas.length}. '
                '¿Guardarlo como privado?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancelar'),
                  child: const Text('Seguir editando'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'privado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F0E0C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar como privado'),
                ),
              ],
            ),
          );
          if (accion != 'privado') return;
          await FirestoreService().actualizarMazo(
            deckId, mazo,
            esPublico: false,
            esAleatorio: _esAleatorio,
          );
        } else {
          await FirestoreService().actualizarMazo(
            deckId, mazo,
            esPublico: _esPublico,
            esAleatorio: _esAleatorio,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mazo actualizado correctamente'),
            backgroundColor: Color(0xFF2D9E6B),
          ),
        );
        Navigator.pop(context, true); // true = hubo cambios
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F0E0C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar mazo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F0E0C),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Info del mazo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E0D6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Información del mazo',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        _campo('Título', _tituloCtrl,
                            'ej. Bioquímica — Metabolismo celular'),
                        const SizedBox(height: 12),
                        const Text('Categoría',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3A3832))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _categorias.contains(_categoria)
                              ? _categoria
                              : _categorias.first,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFAF8F4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE4E0D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE4E0D6)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          items: _categorias
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _categoria = v!),
                        ),
                        const SizedBox(height: 12),
                        // Toggle público/privado: solo para premium
                        if (widget.esPremium) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Publicar para todos',
                                  style: TextStyle(fontSize: 14)),
                              Switch(
                                value: _esPublico,
                                activeTrackColor: const Color(0xFF2D9E6B),
                                onChanged: (v) =>
                                    setState(() => _esPublico = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        // Toggle orden aleatorio: siempre visible
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Orden aleatorio al estudiar',
                                style: TextStyle(fontSize: 14)),
                            Switch(
                              value: _esAleatorio,
                              activeTrackColor: const Color(0xFF2D9E6B),
                              onChanged: (v) =>
                                  setState(() => _esAleatorio = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preguntas
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E0D6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Preguntas',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        ..._preguntas.asMap().entries.map((e) =>
                            _PreguntaEditorEditar(
                              index: e.key,
                              data: e.value,
                              onDelete: () => _eliminarPregunta(e.key),
                              onUpdate: () => setState(() {}),
                            )),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _agregarPregunta,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar pregunta'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFE4E0D6), width: 2),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F0E0C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Guardar cambios →',
                              style: TextStyle(
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

  Widget _campo(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3A3832))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFF7A7770), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFFAF8F4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE4E0D6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE4E0D6)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────
// Editor de pregunta (para EditarMazoScreen)
// ───────────────────────────────────────────────
class _PreguntaEditorEditar extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _PreguntaEditorEditar({
    required this.index,
    required this.data,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_PreguntaEditorEditar> createState() => _PreguntaEditorEditarState();
}

class _PreguntaEditorEditarState extends State<_PreguntaEditorEditar> {
  final List<String> _letras = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pregunta ${widget.index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A7770))),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFE85D3A), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.data['enunciado'] as TextEditingController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Escribe la pregunta aquí…',
              hintStyle:
                  const TextStyle(color: Color(0xFF7A7770), fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4E0D6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE4E0D6)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Opciones — selecciona la correcta',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A3832))),
          const SizedBox(height: 8),
          ...(widget.data['opciones'] as List).asMap().entries.map((e) {
            final i = e.key;
            final opcion = e.value as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        for (var o in widget.data['opciones'] as List) {
                          (o as Map<String, dynamic>)['esCorrecta'] = false;
                        }
                        opcion['esCorrecta'] = true;
                      });
                      widget.onUpdate();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: opcion['esCorrecta'] == true
                            ? const Color(0xFF2D9E6B)
                            : const Color(0xFFE4E0D6),
                      ),
                      child: Center(
                        child: Text(_letras[i],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: opcion['esCorrecta'] == true
                                    ? Colors.white
                                    : const Color(0xFF3A3832))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: opcion['texto'] as TextEditingController,
                          decoration: InputDecoration(
                            hintText: 'Texto opción ${_letras[i]}',
                            hintStyle: const TextStyle(
                                color: Color(0xFF7A7770), fontSize: 13),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE4E0D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE4E0D6)),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: opcion['explicacion']
                              as TextEditingController,
                          decoration: InputDecoration(
                            hintText:
                                'Explicación de por qué es correcta/incorrecta',
                            hintStyle: const TextStyle(
                                color: Color(0xFF7A7770), fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE4E0D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE4E0D6)),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
