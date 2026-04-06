import 'package:hive_flutter/hive_flutter.dart';
import '../models/mazo_local.dart';
import '../study_screen.dart';

class LocalStorageService {
  static const _boxName = 'mazos_locales';

  Box<MazoLocal> get _box => Hive.box<MazoLocal>(_boxName);

  Future<void> guardarMazo(MazoLocal mazo) async {
    await _box.put(mazo.id, mazo);
  }

  List<MazoLocal> obtenerMazos() {
    return _box.values.toList();
  }

  Future<void> eliminarMazo(String id) async {
    await _box.delete(id);
  }

  MazoLocal? obtenerMazo(String id) {
    return _box.get(id);
  }

  int contarMazos() {
    return _box.length;
  }

  /// Convierte MazoLocal a Mazo (para StudyScreen y multi-mazo)
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

  /// Convierte Mazo a MazoLocal (para guardar desde CrearScreen)
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
}
