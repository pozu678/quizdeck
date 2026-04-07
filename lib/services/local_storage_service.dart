import 'package:hive_flutter/hive_flutter.dart';
import '../models/mazo_local.dart';
import '../study_screen.dart';
import '../firestore_service.dart';

class LocalStorageService {
  static const _boxName = 'mazos_locales';

  Box<MazoLocal> get _box => Hive.box<MazoLocal>(_boxName);

  // ── CRUD ────────────────────────────────────────────────────

  Future<void> guardarMazo(MazoLocal mazo) async {
    await _box.put(mazo.id, mazo);
  }

  /// Alias en inglés para guardarMazo.
  Future<void> saveMazo(MazoLocal mazo) => guardarMazo(mazo);

  List<MazoLocal> obtenerMazos() {
    return _box.values.toList();
  }

  /// Alias en inglés para obtenerMazos.
  List<MazoLocal> getMazos() => obtenerMazos();

  Future<void> eliminarMazo(String id) async {
    await _box.delete(id);
  }

  /// Alias en inglés para eliminarMazo.
  Future<void> deleteMazo(String id) => eliminarMazo(id);

  /// Actualiza un mazo existente (reemplaza por id).
  Future<void> updateMazo(MazoLocal mazo) async {
    await _box.put(mazo.id, mazo);
  }

  MazoLocal? obtenerMazo(String id) {
    return _box.get(id);
  }

  int contarMazos() {
    return _box.length;
  }

  // ── Conversores ─────────────────────────────────────────────

  /// Convierte MazoLocal a Mazo (para StudyScreen y multi-mazo).
  Mazo convertirAMazo(MazoLocal local) {
    return Mazo(
      titulo: local.titulo,
      categoria: local.categoria,
      preguntas: local.preguntas
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
          .toList(),
    );
  }

  /// Convierte Mazo a MazoLocal (para guardar desde CrearScreen).
  MazoLocal convertirDeMazo(Mazo mazo, {String? id}) {
    return MazoLocal(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: mazo.titulo,
      categoria: mazo.categoria,
      preguntas: mazo.preguntas
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
      creadoEn: DateTime.now(),
    );
  }

  // ── Migración a Firestore ────────────────────────────────────

  /// Migra todos los mazos locales a Firestore (al activarse Premium).
  /// Evita duplicados comparando titulo + autorUid.
  /// Limpia el box local tras una migración exitosa.
  Future<void> migrateToFirestore(String uid) async {
    final locales = obtenerMazos();
    if (locales.isEmpty) return;

    final firestoreService = FirestoreService();

    // Obtener mazos existentes en Firebase para evitar duplicados
    final existentes = await firestoreService.obtenerMisDecks(uid);
    final titulosExistentes =
        existentes.map((d) => (d['titulo'] as String).toLowerCase()).toSet();

    final migrados = <String>[];

    for (final mazo in locales) {
      final tituloNorm = mazo.titulo.toLowerCase();

      // Saltar si ya existe un mazo con el mismo título
      if (titulosExistentes.contains(tituloNorm)) continue;

      final mazoConvertido = convertirAMazo(mazo);
      await firestoreService.guardarMazo(
        mazoConvertido,
        uid,
        esPublico: mazo.esPublico,
      );

      titulosExistentes.add(tituloNorm);
      migrados.add(mazo.id);
    }

    // Limpiar solo los mazos que se migraron exitosamente
    for (final id in migrados) {
      await _box.delete(id);
    }
  }
}
