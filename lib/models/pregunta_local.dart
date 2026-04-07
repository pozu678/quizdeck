import 'package:hive/hive.dart';
import 'opcion_local.dart';

// TypeId: 1 = PreguntaLocal

class PreguntaLocal {
  String enunciado;
  List<OpcionLocal> opciones;

  PreguntaLocal({required this.enunciado, required this.opciones});
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
