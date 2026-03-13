import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class PendingAttachment extends Equatable {
  const PendingAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.bytes,
  });

  final String id;
  final String name;
  final int size;
  final String mimeType;
  final Uint8List bytes;

  bool get isImage => mimeType.startsWith('image/');

  @override
  List<Object?> get props => [id, name, size, mimeType, bytes];
}
