import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'firestore_service.dart';
import 'study_screen.dart';
import 'widgets/paywall_sheet.dart';
import 'services/local_storage_service.dart';

class CrearScreen extends StatefulWidget {
  const CrearScreen({super.key});

  @override
  State<CrearScreen> createState() => _CrearScreenState();
}

class _CrearScreenState extends State<CrearScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Mis contenidos',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Crea, importa y exporta tus mazos',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF7A7770))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F0E0C),
              unselectedLabelColor: const Color(0xFF7A7770),
              indicatorColor: const Color(0xFFE85D3A),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Crear'),
                Tab(text: 'Importar'),
                Tab(text: 'Exportar'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _CrearTab(),
                  _ImportarTab(),
                  _ExportarTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// PESTAÑA CREAR
// ═══════════════════════════════════════
class _CrearTab extends StatefulWidget {
  const _CrearTab();

  @override
  State<_CrearTab> createState() => _CrearTabState();
}

class _CrearTabState extends State<_CrearTab> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _categoria = 'Medicina';
  bool _esPublico = false;
  bool _esAleatorio = false;
  bool _guardando = false;
  bool _esPremium = false;

  final List<Map<String, dynamic>> _preguntas = [];

  final List<String> _categorias = [
    'Medicina', 'Ciencias', 'Derecho',
    'Historia', 'Matemática', 'Otro'
  ];

  @override
  void initState() {
    super.initState();
    _cargarEstadoPremium();
  }

  Future<void> _cargarEstadoPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final premium = await FirestoreService().obtenerEsPremium(uid);
    if (mounted) setState(() => _esPremium = premium);
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
      final uid = FirebaseAuth.instance.currentUser!.uid;

      if (!_esPremium) {
        // Usuarios free: verificar límite contra almacenamiento local
        final count = LocalStorageService().contarMazos();
        if (count >= 3) {
          if (mounted) {
            setState(() => _guardando = false);
            await mostrarDialogoPremium(context);
          }
          return;
        }
      }

      final preguntas = _preguntas.map((p) {
        final opciones = (p['opciones'] as List).map((o) => Opcion(
          letra: ['A','B','C','D'][(p['opciones'] as List).indexOf(o)],
          texto: (o['texto'] as TextEditingController).text,
          explicacion: (o['explicacion'] as TextEditingController).text,
          esCorrecta: o['esCorrecta'] as bool,
        )).toList();
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

      if (_esPremium) {
        // Premium: verificar mínimo de preguntas si quiere publicar
        if (_esPublico && preguntas.length < 10) {
          if (!mounted) return;
          setState(() => _guardando = false);
          final accion = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Pocas preguntas para publicar'),
              content: Text(
                'Para publicar un mazo necesitas al menos 10 preguntas. '
                'Tu mazo tiene ${preguntas.length} pregunta${preguntas.length == 1 ? '' : 's'}. '
                '¿Quieres guardarlo como privado por ahora?',
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
          // Guardar como privado
          await FirestoreService().guardarMazo(mazo, uid, esPublico: false);
        } else {
          // Verificar límite de publicaciones del mes
          if (_esPublico) {
            final publicacionesMes =
                await FirestoreService().contarPublicacionesMes(uid);
            if (publicacionesMes >= 3) {
              if (!mounted) return;
              setState(() => _guardando = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Has alcanzado el límite de 3 publicaciones este mes. '
                    'Podrás publicar más el próximo mes.',
                  ),
                ),
              );
              return;
            }
          }
          await FirestoreService().guardarMazo(mazo, uid, esPublico: _esPublico);
        }
      } else {
        // Free: guardar localmente, siempre privado
        final mazoLocal = LocalStorageService().convertirDeMazo(mazo);
        await LocalStorageService().guardarMazo(mazoLocal);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esPremium
                ? '✅ Mazo guardado${_esPublico ? ' y publicado' : ''} correctamente'
                : '✅ Mazo guardado en tu dispositivo'),
            backgroundColor: const Color(0xFF2D9E6B),
          ),
        );
        _tituloCtrl.clear();
        _descCtrl.clear();
        setState(() {
          _preguntas.clear();
          _esPublico = false;
          _esAleatorio = false;
        });
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
    return SingleChildScrollView(
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
                _campo('Descripción', _descCtrl,
                    '¿Para qué examen sirve?', maxLines: 2),
                const SizedBox(height: 12),
                const Text('Categoría',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600,
                        color: Color(0xFF3A3832))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
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
                // Toggle publicar: solo visible para premium
                if (_esPremium) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Publicar para todos',
                          style: TextStyle(fontSize: 14)),
                      Switch(
                        value: _esPublico,
                        activeTrackColor: const Color(0xFF2D9E6B),
                        onChanged: (v) => setState(() => _esPublico = v),
                      ),
                    ],
                  ),
                ],
                // Toggle orden aleatorio: siempre visible
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Orden aleatorio al estudiar',
                        style: TextStyle(fontSize: 14)),
                    Switch(
                      value: _esAleatorio,
                      activeTrackColor: const Color(0xFF2D9E6B),
                      onChanged: (v) => setState(() => _esAleatorio = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Banner informativo para usuarios free
          if (!_esPremium) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E0D6)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '💡 Hazte Premium para publicar tus mazos y compartirlos con la comunidad',
                      style: TextStyle(
                          fontSize: 12.5, color: Color(0xFF3A3832)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => mostrarDialogoPremium(context),
                    child: const Text('Ver Premium',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE85D3A),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
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
                    _PreguntaEditor(
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
                      child:
                          CircularProgressIndicator(strokeWidth: 2,
                              color: Colors.white),
                    )
                  : Text(
                      _esPremium
                          ? 'Guardar mazo →'
                          : 'Guardar en mi dispositivo →',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl,
      String hint, {int maxLines = 1}) {
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════
// EDITOR DE PREGUNTA
// ═══════════════════════════════════════
class _PreguntaEditor extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _PreguntaEditor({
    required this.index,
    required this.data,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_PreguntaEditor> createState() => _PreguntaEditorState();
}

class _PreguntaEditorState extends State<_PreguntaEditor> {
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
                          (o as Map<String, dynamic>)['esCorrecta'] =
                              false;
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
                          controller: opcion['texto']
                              as TextEditingController,
                          decoration: InputDecoration(
                            hintText: 'Texto opción ${_letras[i]}',
                            hintStyle: const TextStyle(
                                color: Color(0xFF7A7770),
                                fontSize: 13),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE4E0D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE4E0D6)),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: opcion['explicacion']
                              as TextEditingController,
                          decoration: InputDecoration(
                            hintText: 'Explicación de por qué es correcta/incorrecta',
                            hintStyle: const TextStyle(
                                color: Color(0xFF7A7770),
                                fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE4E0D6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE4E0D6)),
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

// ═══════════════════════════════════════
// PESTAÑA IMPORTAR
// ═══════════════════════════════════════
class _ImportarTab extends StatefulWidget {
  const _ImportarTab();

  @override
  State<_ImportarTab> createState() => _ImportarTabState();
}

class _ImportarTabState extends State<_ImportarTab> {
  Mazo? _mazoPreview;
  bool _importando = false;
  bool _esPremium = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadoPremium();
  }

  Future<void> _cargarEstadoPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final premium = await FirestoreService().obtenerEsPremium(uid);
    if (mounted) setState(() => _esPremium = premium);
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null) return;
    final file = File(result.files.single.path!);
    final contenido = await file.readAsString();
    final nombreArchivo =
        result.files.single.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '').trim();
    final mazo = _parsearTxt(contenido, tituloFallback: nombreArchivo);
    if (mazo != null) {
      setState(() => _mazoPreview = mazo);
    }
  }

  void _mostrarErrorParser(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $mensaje')),
    );
  }

  // Normaliza "Justificación" → "Justificacion" para comparar sin tilde
  String _normJust(String s) => s
      .replaceAll('á', 'a')
      .replaceAll('Á', 'A')
      .replaceAll('é', 'e')
      .replaceAll('É', 'E')
      .replaceAll('í', 'i')
      .replaceAll('Í', 'I')
      .replaceAll('ó', 'o')
      .replaceAll('Ó', 'O')
      .replaceAll('ú', 'u')
      .replaceAll('Ú', 'U');

  // Regex compilados una sola vez
  static final _reOpcion =
      RegExp(r'^([a-dA-D])\)\s*(.+)$');
  static final _reRespuesta =
      RegExp(r'^[Rr]espuesta:\s*([a-dA-D])\s*$', caseSensitive: false);
  static final _reJust =
      RegExp(r'^[Jj]ustificaci[oó]n\s+([a-dA-D])\):\s*(.+)$',
          caseSensitive: false);
  static final _reEncabezadoPregunta =
      RegExp(r'^\d+\.-\s*');

  Mazo? _parsearTxt(String texto, {String tituloFallback = 'Mazo importado'}) {
    // Normalizar saltos de línea y recortar cada línea
    final lineas = texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .toList();

    String titulo = tituloFallback;
    String categoria = 'General';
    int i = 0;

    // Cabeceras opcionales (#MAZO:, #CATEGORIA:)
    while (i < lineas.length && lineas[i].startsWith('#')) {
      if (lineas[i].startsWith('#MAZO:')) {
        titulo = lineas[i].replaceFirst('#MAZO:', '').trim();
      } else if (lineas[i].startsWith('#CATEGORIA:')) {
        categoria = lineas[i].replaceFirst('#CATEGORIA:', '').trim();
      }
      i++;
    }

    // Agrupar en bloques: cada bloque empieza con línea "N.-"
    final bloques = <List<String>>[];
    List<String>? bloque;
    for (; i < lineas.length; i++) {
      final linea = lineas[i];
      if (_reEncabezadoPregunta.hasMatch(linea)) {
        if (bloque != null) bloques.add(bloque);
        bloque = [linea];
      } else if (bloque != null) {
        bloque.add(linea);
      }
    }
    if (bloque != null) bloques.add(bloque);

    if (bloques.isEmpty) {
      _mostrarErrorParser('No se encontraron preguntas en el archivo.');
      return null;
    }

    final preguntas = <Pregunta>[];

    for (int b = 0; b < bloques.length; b++) {
      final numPregunta = b + 1;
      final lb = bloques[b].where((l) => l.isNotEmpty).toList();

      // Enunciado: primera línea sin el prefijo "N.-"
      final enunciado = lb[0].replaceFirst(_reEncabezadoPregunta, '').trim();
      if (enunciado.isEmpty) {
        _mostrarErrorParser('Error en pregunta $numPregunta: falta el enunciado');
        return null;
      }

      final textos = <String, String>{};   // clave: 'a'–'d' minúsculas
      String? correcta;                    // letra minúscula
      final explicaciones = <String, String>{};

      for (int j = 1; j < lb.length; j++) {
        final linea = lb[j];

        // a) texto
        final mOpt = _reOpcion.firstMatch(linea);
        if (mOpt != null) {
          textos[mOpt.group(1)!.toLowerCase()] = mOpt.group(2)!.trim();
          continue;
        }

        // Respuesta: b
        final mResp = _reRespuesta.firstMatch(linea);
        if (mResp != null) {
          correcta = mResp.group(1)!.toLowerCase();
          continue;
        }

        // Justificación a): texto  (también sin tilde)
        final mJust = _reJust.firstMatch(linea);
        if (mJust != null) {
          explicaciones[mJust.group(1)!.toLowerCase()] =
              mJust.group(2)!.trim();
          continue;
        }
      }

      // Validaciones
      if (correcta == null) {
        _mostrarErrorParser(
            'Error en pregunta $numPregunta: falta Respuesta:');
        return null;
      }
      for (final letra in ['a', 'b', 'c', 'd']) {
        if (!textos.containsKey(letra)) {
          _mostrarErrorParser(
              'Error en pregunta $numPregunta: falta opción $letra)');
          return null;
        }
        if (!explicaciones.containsKey(letra)) {
          _mostrarErrorParser(
              'Error en pregunta $numPregunta: falta Justificación $letra):');
          return null;
        }
      }

      preguntas.add(Pregunta(
        enunciado: enunciado,
        opciones: ['a', 'b', 'c', 'd']
            .map((letra) => Opcion(
                  letra: letra.toUpperCase(),
                  texto: textos[letra]!,
                  explicacion: explicaciones[letra]!,
                  esCorrecta: letra == correcta,
                ))
            .toList(),
      ));
    }

    if (preguntas.isEmpty) {
      _mostrarErrorParser('No se encontraron preguntas válidas en el archivo.');
      return null;
    }

    return Mazo(titulo: titulo, categoria: categoria, preguntas: preguntas);
  }

  Future<void> _confirmarImport() async {
    if (_mazoPreview == null) return;
    setState(() => _importando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      if (_esPremium) {
        await FirestoreService().guardarMazo(_mazoPreview!, uid, esPublico: false);
      } else {
        // Free: verificar límite local
        final count = LocalStorageService().contarMazos();
        if (count >= 3) {
          if (mounted) {
            setState(() => _importando = false);
            await mostrarDialogoPremium(context);
          }
          return;
        }
        final mazoLocal =
            LocalStorageService().convertirDeMazo(_mazoPreview!);
        await LocalStorageService().guardarMazo(mazoLocal);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esPremium
                ? '✅ Mazo importado correctamente'
                : '✅ Mazo guardado en tu dispositivo'),
            backgroundColor: const Color(0xFF2D9E6B),
          ),
        );
        setState(() => _mazoPreview = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _importando = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Zona de carga
          GestureDetector(
            onTap: _seleccionarArchivo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE4E0D6),
                    width: 2,
                    style: BorderStyle.solid),
              ),
              child: Column(
                children: const [
                  Icon(Icons.upload_file_outlined,
                      size: 40, color: Color(0xFF7A7770)),
                  SizedBox(height: 12),
                  Text('Toca para seleccionar archivo .txt',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3A3832))),
                  SizedBox(height: 4),
                  Text('Formato QuizDeck .txt',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF7A7770))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preview
          if (_mazoPreview != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D9E6B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vista previa',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D9E6B))),
                  const SizedBox(height: 8),
                  Text(_mazoPreview!.titulo,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                      '${_mazoPreview!.preguntas.length} preguntas · ${_mazoPreview!.categoria}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF7A7770))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _importando ? null : _confirmarImport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9E6B),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _importando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('✓ Importar este mazo',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Formato
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4E0D6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Formato del archivo',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                Text(
                  '1.- ¿Enunciado de la pregunta?\na) Opción\nb) Opción\nc) Opción\nd) Opción\nRespuesta: b\nJustificación a): texto\nJustificación b): texto\nJustificación c): texto\nJustificación d): texto\n\n2.- ¿Siguiente pregunta?\n...\n\nLas preguntas se separan con una línea en blanco\nseguida del siguiente número con ".-"',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF3A3832),
                      height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// PESTAÑA EXPORTAR
// ═══════════════════════════════════════
class _ExportarTab extends StatefulWidget {
  const _ExportarTab();

  @override
  State<_ExportarTab> createState() => _ExportarTabState();
}

class _ExportarTabState extends State<_ExportarTab> {
  List<Map<String, dynamic>> _misDecks = [];
  bool _cargando = true;
  String? _exportandoId;

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

  Future<void> _exportarMazo(Map<String, dynamic> deck) async {
    setState(() => _exportandoId = deck['id'] as String?);
    try {
      final mazo =
          await FirestoreService().obtenerMazoCompleto(deck);
      if (mazo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Este mazo no tiene preguntas aún')),
          );
        }
        return;
      }
      final buf = StringBuffer()
        ..writeln('#QUIZDECK v1')
        ..writeln('#MAZO: ${mazo.titulo}')
        ..writeln('#CATEGORIA: ${mazo.categoria}');
      for (final pregunta in mazo.preguntas) {
        buf.writeln();
        buf.writeln('---');
        buf.writeln(pregunta.enunciado);
        for (final opcion in pregunta.opciones) {
          final tag = opcion.esCorrecta ? ' [CORRECTA]' : '';
          buf.writeln(
              '${opcion.letra}) ${opcion.texto} | ${opcion.explicacion}$tag');
        }
      }
      buf.writeln('---');
      await Share.share(
        buf.toString(),
        subject: '${mazo.titulo}.txt',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_misDecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.folder_open_outlined,
                size: 48, color: Color(0xFF7A7770)),
            SizedBox(height: 12),
            Text('Aún no tienes mazos creados',
                style: TextStyle(
                    fontSize: 15, color: Color(0xFF7A7770))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _misDecks.length,
      itemBuilder: (_, i) {
        final deck = _misDecks[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E0D6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck['titulo'] ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text(deck['categoria'] ?? '',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7A7770))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportandoId == deck['id']
                    ? null
                    : () => _exportarMazo(deck),
                icon: _exportandoId == deck['id']
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_outlined,
                        size: 16),
                label: const Text('Exportar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F0E0C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}