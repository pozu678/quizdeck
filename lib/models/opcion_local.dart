import 'package:hive/hive.dart';

// TypeId: 2 = OpcionLocal

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
