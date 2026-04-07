import 'package:hive/hive.dart';
import 'pregunta_local.dart';

export 'pregunta_local.dart';
export 'opcion_local.dart';

// TypeIds: 0 = MazoLocal, 1 = PreguntaLocal, 2 = OpcionLocal

class MazoLocal extends HiveObject {
  String id;
  String titulo;
  String categoria;
  bool esPublico;
  List<PreguntaLocal> preguntas;
  bool sincronizado;
  String? firebaseId;
  DateTime creadoEn;

  MazoLocal({
    required this.id,
    required this.titulo,
    required this.categoria,
    this.esPublico = false,
    required this.preguntas,
    this.sincronizado = false,
    this.firebaseId,
    required this.creadoEn,
  });
}

// ── Adapter manual ─────────────────────────────────────────────

class MazoLocalAdapter extends TypeAdapter<MazoLocal> {
  @override
  final int typeId = 0;

  @override
  MazoLocal read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return MazoLocal(
      id: fields[0] as String,
      titulo: fields[1] as String,
      categoria: fields[2] as String,
      preguntas: (fields[3] as List).cast<PreguntaLocal>(),
      sincronizado: fields[4] as bool,
      firebaseId: fields[5] as String?,
      creadoEn: fields[6] as DateTime,
      // field 7 added later; default false for existing records
      esPublico: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, MazoLocal obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.titulo)
      ..writeByte(2)
      ..write(obj.categoria)
      ..writeByte(3)
      ..write(obj.preguntas)
      ..writeByte(4)
      ..write(obj.sincronizado)
      ..writeByte(5)
      ..write(obj.firebaseId)
      ..writeByte(6)
      ..write(obj.creadoEn)
      ..writeByte(7)
      ..write(obj.esPublico);
  }
}
