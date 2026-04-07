import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_screen.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Usuario ──
  Future<void> crearUsuario(User user) async {
    final doc = _db.collection('users').doc(user.uid);
    final existe = await doc.get();
    if (!existe.exists) {
      await doc.set({
        'uid': user.uid,
        'nombre': user.displayName ?? '',
        'email': user.email ?? '',
        'esPremium': false,
        'mazosCreados': 0,
        'racha': 0,
        'sesionesHoy': 0,
        'fechaUltimaSesion': '',
        'creadoEn': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Guardar mazo ──
  Future<void> guardarMazo(Mazo mazo, String uid, {bool esPublico = false}) async {
    final ref = _db.collection('decks').doc();
    await ref.set({
      'id': ref.id,
      'titulo': mazo.titulo,
      'categoria': mazo.categoria,
      'autorUid': uid,
      'esPublico': esPublico,
      'descargas': 0,
      'rating': 0,
      'creadoEn': FieldValue.serverTimestamp(),
    });
    for (final pregunta in mazo.preguntas) {
      await ref.collection('questions').add({
        'enunciado': pregunta.enunciado,
        'opciones': pregunta.opciones
            .map((o) => {
                  'letra': o.letra,
                  'texto': o.texto,
                  'explicacion': o.explicacion,
                  'esCorrecta': o.esCorrecta,
                })
            .toList(),
      });
    }
  }

  // ── Leer mazo completo con preguntas ──
  Future<Mazo?> obtenerMazoCompleto(
      Map<String, dynamic> deckData) async {
    try {
      final deckId = deckData['id'] as String?;
      if (deckId == null) return null;
      final snap = await _db
          .collection('decks')
          .doc(deckId)
          .collection('questions')
          .get();
      if (snap.docs.isEmpty) return null;
      final preguntas = snap.docs.map((doc) {
        final data = doc.data();
        final opciones =
            (data['opciones'] as List).map((o) => Opcion(
                  letra: o['letra'] ?? '',
                  texto: o['texto'] ?? '',
                  explicacion: o['explicacion'] ?? '',
                  esCorrecta: o['esCorrecta'] ?? false,
                )).toList();
        return Pregunta(
          enunciado: data['enunciado'] ?? '',
          opciones: opciones,
        );
      }).toList();
      return Mazo(
        titulo: deckData['titulo'] ?? '',
        categoria: deckData['categoria'] ?? '',
        preguntas: preguntas,
      );
    } catch (e) {
      return null;
    }
  }

  // ── Actualizar mazo existente ──
  Future<void> actualizarMazo(
    String deckId,
    Mazo mazo, {
    bool esPublico = false,
    bool esAleatorio = false,
  }) async {
    final ref = _db.collection('decks').doc(deckId);
    await ref.update({
      'titulo': mazo.titulo,
      'categoria': mazo.categoria,
      'esPublico': esPublico,
      'esAleatorio': esAleatorio,
    });
    // Reemplazar preguntas: eliminar viejas y agregar nuevas
    final oldQuestions = await ref.collection('questions').get();
    for (final doc in oldQuestions.docs) {
      await doc.reference.delete();
    }
    for (final pregunta in mazo.preguntas) {
      await ref.collection('questions').add({
        'enunciado': pregunta.enunciado,
        'opciones': pregunta.opciones
            .map((o) => {
                  'letra': o.letra,
                  'texto': o.texto,
                  'explicacion': o.explicacion,
                  'esCorrecta': o.esCorrecta,
                })
            .toList(),
      });
    }
  }

  // ── Eliminar mazo ──
  Future<void> eliminarMazo(String deckId) async {
    final ref = _db.collection('decks').doc(deckId);
    final questions = await ref.collection('questions').get();
    for (final doc in questions.docs) {
      await doc.reference.delete();
    }
    await ref.delete();
  }

  // ── Mazos públicos ──
  Future<List<Map<String, dynamic>>> obtenerMazosPublicos() async {
    final snap = await _db
        .collection('decks')
        .where('esPublico', isEqualTo: true)
        .orderBy('creadoEn', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  // ── Mis mazos ──
  Future<List<Map<String, dynamic>>> obtenerMisDecks(
      String uid) async {
    final snap = await _db
        .collection('decks')
        .where('autorUid', isEqualTo: uid)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  // ── Premium ──
  Future<bool> obtenerEsPremium(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['esPremium'] == true;
  }

  Future<void> activarPremium(String uid) async {
    await _db.collection('users').doc(uid).update({'esPremium': true});
  }

  // ── Sesiones de estudio diarias ──

  /// Verifica si el usuario puede hacer una sesión de estudio.
  /// Si el día cambió, resetea el contador. Retorna true si puede estudiar.
  Future<bool> puedeEstudiar(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return true;

    final sesionesHoy = (data['sesionesHoy'] as int?) ?? 0;
    final fechaStr = (data['fechaUltimaSesion'] as String?) ?? '';
    final hoy = _fechaHoy();

    // Si la fecha cambió, resetear contador
    if (fechaStr != hoy) {
      await _db.collection('users').doc(uid).update({
        'sesionesHoy': 0,
        'fechaUltimaSesion': hoy,
      });
      return true;
    }

    return sesionesHoy < 5;
  }

  /// Registra una sesión de estudio incrementando el contador.
  Future<void> registrarSesion(String uid) async {
    final hoy = _fechaHoy();
    await _db.collection('users').doc(uid).update({
      'sesionesHoy': FieldValue.increment(1),
      'fechaUltimaSesion': hoy,
    });
  }

  /// Agrega sesiones extra (usado por rewarded ads). Resta del contador.
  Future<void> agregarSesionesExtra(String uid, int extra) async {
    await _db.collection('users').doc(uid).update({
      'sesionesHoy': FieldValue.increment(-extra),
    });
  }

  String _fechaHoy() {
    final ahora = DateTime.now();
    return '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';
  }

  // ── Progreso y K-Score ──
  Future<void> guardarProgreso({
    required String uid,
    required String deckId,
    required int correctas,
    required int total,
    double kScore = 0,
    int tiempoPromedio = 0,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(deckId)
        .set({
      'correctas': correctas,
      'total': total,
      'porcentaje': (correctas / total * 100).round(),
      'kScore': kScore,
      'tiempoPromedio': tiempoPromedio,
      'ultimaSesion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Calcula el K-Score promedio del usuario a partir de todos sus progresos.
  Future<double> obtenerKScorePromedio(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();
      if (snap.docs.isEmpty) return 0;
      double total = 0;
      int count = 0;
      for (final doc in snap.docs) {
        final k = (doc.data()['kScore'] as num?)?.toDouble() ?? 0;
        if (k > 0) {
          total += k;
          count++;
        }
      }
      return count == 0 ? 0 : total / count;
    } catch (_) {
      return 0;
    }
  }

  // ── Duelos ──

  static const _codigoChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _generarCodigo() {
    final rand = Random();
    return List.generate(6, (_) => _codigoChars[rand.nextInt(_codigoChars.length)])
        .join();
  }

  /// Crea un nuevo duelo y retorna el código de 6 caracteres.
  Future<String> crearDuelo({
    required String uid,
    required String nombre,
    required String deckId,
    required String deckTitulo,
    required List<Map<String, dynamic>> preguntas,
  }) async {
    final codigo = _generarCodigo();
    final ref = _db.collection('duelos').doc();

    await ref.set({
      'id': ref.id,
      'creadorUid': uid,
      'creadorNombre': nombre,
      'retadorUid': null,
      'retadorNombre': null,
      'deckId': deckId,
      'deckTitulo': deckTitulo,
      'estado': 'esperando',
      'preguntaActual': 0,
      'totalPreguntas': preguntas.length,
      'respuestasCreador': [],
      'respuestasRetador': [],
      'ganadorUid': null,
      'codigo': codigo,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    // Guardar preguntas en subcolección
    for (int i = 0; i < preguntas.length; i++) {
      await ref.collection('preguntas').doc('$i').set({
        'idx': i,
        ...preguntas[i],
      });
    }

    return codigo;
  }

  /// Busca un duelo por código de 6 caracteres.
  Future<Map<String, dynamic>?> buscarDueloPorCodigo(String codigo) async {
    try {
      final snap = await _db
          .collection('duelos')
          .where('codigo', isEqualTo: codigo.toUpperCase())
          .where('estado', isEqualTo: 'esperando')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      data['id'] = snap.docs.first.id;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// El retador se une al duelo.
  Future<void> unirseDuelo({
    required String dueloId,
    required String uid,
    required String nombre,
  }) async {
    await _db.collection('duelos').doc(dueloId).update({
      'retadorUid': uid,
      'retadorNombre': nombre,
      'estado': 'en_curso',
    });
  }

  /// Guarda una respuesta en el duelo.
  Future<void> guardarRespuestaDuelo({
    required String dueloId,
    required bool esCreador,
    required Map<String, dynamic> respuesta,
  }) async {
    final campo =
        esCreador ? 'respuestasCreador' : 'respuestasRetador';
    await _db.collection('duelos').doc(dueloId).update({
      campo: FieldValue.arrayUnion([respuesta]),
    });
  }

  /// Marca el duelo como terminado con el ganador.
  Future<void> terminarDuelo({
    required String dueloId,
    required String? ganadorUid,
  }) async {
    await _db.collection('duelos').doc(dueloId).update({
      'estado': 'terminado',
      'ganadorUid': ganadorUid,
    });
  }

  /// Stream del documento del duelo para escuchar cambios en tiempo real.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDuelo(String dueloId) {
    return _db.collection('duelos').doc(dueloId).snapshots();
  }

  /// Obtiene las preguntas guardadas del duelo.
  Future<List<Map<String, dynamic>>> obtenerPreguntasDuelo(
      String dueloId) async {
    final snap = await _db
        .collection('duelos')
        .doc(dueloId)
        .collection('preguntas')
        .orderBy('idx')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Selecciona N preguntas aleatorias de un mazo para un duelo.
  Future<List<Map<String, dynamic>>> seleccionarPreguntasParaDuelo({
    required String deckId,
    int cantidad = 10,
  }) async {
    final snap = await _db
        .collection('decks')
        .doc(deckId)
        .collection('questions')
        .get();
    final todas = snap.docs.map((d) => d.data()).toList();
    todas.shuffle();
    return todas.take(min(cantidad, todas.length)).toList();
  }

  // ── Publicaciones por mes ──

  /// Cuenta cuántos mazos públicos creó el usuario este mes.
  Future<int> contarPublicacionesMes(String uid) async {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    final snap = await _db
        .collection('decks')
        .where('autorUid', isEqualTo: uid)
        .where('esPublico', isEqualTo: true)
        .where('creadoEn',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
        .get();
    return snap.docs.length;
  }

  // ── Sincronización local → Firebase ──

  /// Sube los mazos locales no sincronizados a Firebase (al hacerse premium).
  Future<void> sincronizarMazosLocales(
      String uid, List<dynamic> mazosLocales) async {
    for (final mazo in mazosLocales) {
      if (mazo.sincronizado == true) continue;
      final mazoConvertido = Mazo(
        titulo: mazo.titulo as String,
        categoria: mazo.categoria as String,
        preguntas: (mazo.preguntas as List).map((p) {
          return Pregunta(
            enunciado: p.enunciado as String,
            opciones: (p.opciones as List).map((o) {
              return Opcion(
                letra: o.letra as String,
                texto: o.texto as String,
                explicacion: o.explicacion as String,
                esCorrecta: o.esCorrecta as bool,
              );
            }).toList(),
          );
        }).toList(),
      );
      await guardarMazo(mazoConvertido, uid, esPublico: false);
      mazo.sincronizado = true;
      await mazo.save();
    }
  }

  // ── Reportes de mazos ──

  /// Reporta un mazo. Retorna true si se guardó, false si ya existía.
  Future<bool> reportarMazo({
    required String deckId,
    required String reportadorUid,
    required String razon,
  }) async {
    final existente = await _db
        .collection('reportes')
        .where('deckId', isEqualTo: deckId)
        .where('reportadorUid', isEqualTo: reportadorUid)
        .limit(1)
        .get();
    if (existente.docs.isNotEmpty) return false;
    await _db.collection('reportes').add({
      'deckId': deckId,
      'reportadorUid': reportadorUid,
      'razon': razon,
      'creadoEn': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
