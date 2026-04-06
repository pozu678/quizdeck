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
        'creadoEn': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Guardar mazo ──
  Future<void> guardarMazo(Mazo mazo, String uid) async {
    final ref = _db.collection('decks').doc();
    await ref.set({
      'id': ref.id,
      'titulo': mazo.titulo,
      'categoria': mazo.categoria,
      'autorUid': uid,
      'esPublico': true,
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

  // ── Progreso ──
  Future<void> guardarProgreso({
    required String uid,
    required String deckId,
    required int correctas,
    required int total,
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
      'ultimaSesion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}