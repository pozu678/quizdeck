import 'package:hive/hive.dart';

// TypeIds: 0 = MazoLocal, 1 = PreguntaLocal, 2 = OpcionLocal

class MazoLocal extends HiveObject {
  String id;
  String titulo;
  String categoria;
  List<PreguntaLocal> preguntas;
  bool sincronizado;
  String? firebaseId;
  DateTime creadoEn;

  MazoLocal({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.preguntas,
    this.sincronizado = false,
    this.firebaseId,
    required this.creadoEn,
  });
}

class PreguntaLocal {
  String enunciado;
  List<OpcionLocal> opciones;

  PreguntaLocal({required this.enunciado, required this.opciones});
}

class OpcionLocal {
  String letra;
  String texto;
  String explicacion;
  bool esCorrecta;

  OpcionLocal({
    required this.letra,
    required this.texto,
    required this.explicacion,
    required this.esCorrecta,
  });
}

// ── Adapters manuales ──────────────────────────────────────────

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
    );
  }

  @override
  void write(BinaryWriter writer, MazoLocal obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.creadoEn);
  }
}

class PreguntaLocalAdapter extends TypeAdapter<PreguntaLocal> {
  @override
  final int typeId = 1;

  @override
  PreguntaLocal read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return PreguntaLocal(
      enunciado: fields[0] as String,
      opciones: (fields[1] as List).cast<OpcionLocal>(),
    );
  }

  @override
  void write(BinaryWriter writer, PreguntaLocal obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.enunciado)
      ..writeByte(1)
      ..write(obj.opciones);
  }
}

class OpcionLocalAdapter extends TypeAdapter<OpcionLocal> {
  @override
  final int typeId = 2;

  @override
  OpcionLocal read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return OpcionLocal(
      letra: fields[0] as String,
      texto: fields[1] as String,
      explicacion: fields[2] as String,
      esCorrecta: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OpcionLocal obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.letra)
      ..writeByte(1)
      ..write(obj.texto)
      ..writeByte(2)
      ..write(obj.explicacion)
      ..writeByte(3)
      ..write(obj.esCorrecta);
  }
}
