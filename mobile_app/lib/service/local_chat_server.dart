import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef DirectMessageHandler = void Function(DirectTextPayload message);
typedef PeerMetaHandler = void Function(DirectPeerMetaPayload payload);
typedef FileReceivedHandler = void Function(DirectFilePayload file);
typedef FileProgressHandler = void Function(String transferId, double progress);
typedef FileDeliveredHandler = void Function(String transferId);
typedef ServerStatusHandler = void Function(String status);
typedef RemoteDisconnectHandler = void Function();

const _binaryFileChunkFrame = 1;
const _chunkPumpDelay = Duration(milliseconds: 8);

class DirectTextPayload {
  const DirectTextPayload({
    required this.text,
    required this.sender,
    this.compositionId,
  });

  final String text;
  final String sender;
  final String? compositionId;
}

class DirectPeerMetaPayload {
  const DirectPeerMetaPayload({
    required this.role,
    required this.name,
    required this.address,
    this.deviceInfo,
  });

  final String role;
  final String name;
  final String address;
  final String? deviceInfo;
}

class DirectFilePayload {
  const DirectFilePayload({
    required this.transferId,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.bytes,
    required this.sender,
    this.compositionId,
    this.batchId,
    this.batchTotal,
  });

  final String transferId;
  final String name;
  final String mimeType;
  final int size;
  final Uint8List bytes;
  final String sender;
  final String? compositionId;
  final String? batchId;
  final int? batchTotal;
}

class _IncomingFile {
  _IncomingFile({
    required this.transferId,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.sender,
    this.compositionId,
    this.batchId,
    this.batchTotal,
    required this.chunkSize,
    required this.totalChunks,
  }) : chunks = List<Uint8List?>.filled(totalChunks, null, growable: false);

  final String transferId;
  final String name;
  final String mimeType;
  final int size;
  final String sender;
  final String? compositionId;
  final String? batchId;
  final int? batchTotal;
  final int chunkSize;
  final int totalChunks;
  final List<Uint8List?> chunks;
  int receivedBytes = 0;

  int contiguousCount() {
    var count = 0;
    while (count < chunks.length && chunks[count] != null) {
      count += 1;
    }
    return count;
  }

  bool get isComplete => contiguousCount() == totalChunks;
}

class _OutgoingFile {
  _OutgoingFile({
    required this.transferId,
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.compositionId,
    this.batchId,
    this.batchTotal,
    required this.chunkSize,
  }) : totalChunks = (bytes.length / chunkSize).ceil();

  final String transferId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? compositionId;
  final String? batchId;
  final int? batchTotal;
  final int chunkSize;
  final int totalChunks;
  int nextChunk = 0;
  bool isSending = false;
}

class LocalChatServer {
  LocalChatServer({
    required this.onBrowserMessage,
    required this.onPeerMeta,
    required this.onFileReceived,
    required this.onFileProgress,
    required this.onFileDelivered,
    required this.onStatusChanged,
    required this.onRemoteDisconnect,
  });

  DirectMessageHandler onBrowserMessage;
  PeerMetaHandler onPeerMeta;
  FileReceivedHandler onFileReceived;
  FileProgressHandler onFileProgress;
  FileDeliveredHandler onFileDelivered;
  ServerStatusHandler onStatusChanged;
  RemoteDisconnectHandler onRemoteDisconnect;

  HttpServer? _server;
  WebSocket? _socket;
  String? _token;
  final Map<String, _IncomingFile> _incomingFiles = {};
  final Map<String, _OutgoingFile> _outgoingFiles = {};
  bool _isStopping = false;

  bool get isRunning => _server != null;

  Future<void> start({required int port, required String token}) async {
    await stop();

    _isStopping = false;
    _token = token;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    onStatusChanged('Listening on port $port');
    unawaited(_listen());
  }

  Future<void> _listen() async {
    final server = _server;
    if (server == null) {
      return;
    }

    await for (final request in server) {
      final queryToken = request.uri.queryParameters['token'];

      if (request.uri.path != '/ws' || queryToken != _token) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        continue;
      }

      final socket = await WebSocketTransformer.upgrade(request);
      _socket = socket;
      onStatusChanged('Browser connected directly');
      socket.add(
        jsonEncode({'type': 'system', 'text': 'Direct socket connected'}),
      );

      for (final outgoing in _outgoingFiles.values) {
        _sendFileOffer(socket, outgoing);
      }

      socket.listen(
        (raw) {
          try {
            if (raw is List<int>) {
              _handleBinaryChunk(Uint8List.fromList(raw));
              return;
            }

            final payload = jsonDecode(raw as String) as Map<String, dynamic>;
            switch (payload['type']) {
              case 'message':
                final text = payload['text']?.toString().trim() ?? '';
                if (text.isNotEmpty) {
                  onBrowserMessage(
                    DirectTextPayload(
                      text: text,
                      sender: payload['sender']?.toString() ?? 'browser',
                      compositionId: payload['compositionId']?.toString(),
                    ),
                  );
                }
                break;
              case 'peer_meta':
                final role = payload['role']?.toString().trim() ?? '';
                final name = payload['name']?.toString().trim() ?? '';
                final address = payload['address']?.toString().trim() ?? '';
                if (role.isNotEmpty && name.isNotEmpty && address.isNotEmpty) {
                  onPeerMeta(
                    DirectPeerMetaPayload(
                      role: role,
                      name: name,
                      address: address,
                      deviceInfo: payload['deviceInfo']?.toString().trim(),
                    ),
                  );
                }
                break;
              case 'file_offer':
                _handleFileOffer(payload);
                break;
              case 'file_resume':
                _handleFileResume(payload);
                break;
              case 'file_chunk':
                _handleFileChunk(payload);
                break;
              case 'file_complete':
                _handleFileComplete(payload);
                break;
              case 'file_received':
                _handleFileReceived(payload);
                break;
              case 'file_cancel':
                _handleFileCancel(payload);
                break;
              case 'disconnect':
                onRemoteDisconnect();
                unawaited(stop());
                break;
              case 'ping':
                socket.add(jsonEncode({'type': 'pong'}));
                break;
            }
          } catch (_) {
            socket.add(
              jsonEncode({'type': 'error', 'text': 'Invalid JSON message'}),
            );
          }
        },
        onDone: () {
          if (identical(_socket, socket)) {
            _socket = null;
            if (!_isStopping) {
              onStatusChanged('Waiting for browser reconnect');
            }
          }
        },
      );
    }
  }

  void _handleFileOffer(Map<String, dynamic> payload) {
    final socket = _socket;
    final transferId = payload['transferId']?.toString();
    final name = payload['name']?.toString();
    final mimeType =
        payload['mimeType']?.toString() ?? 'application/octet-stream';
    final size = payload['size'] is int
        ? payload['size'] as int
        : int.tryParse(payload['size']?.toString() ?? '');
    final chunkSize = payload['chunkSize'] is int
        ? payload['chunkSize'] as int
        : int.tryParse(payload['chunkSize']?.toString() ?? '');
    final totalChunks = payload['totalChunks'] is int
        ? payload['totalChunks'] as int
        : int.tryParse(payload['totalChunks']?.toString() ?? '');

    if (socket == null ||
        transferId == null ||
        name == null ||
        size == null ||
        chunkSize == null ||
        totalChunks == null) {
      return;
    }

    _incomingFiles.putIfAbsent(
      transferId,
      () => _IncomingFile(
        transferId: transferId,
        name: name,
        mimeType: mimeType,
        size: size,
        sender: payload['sender']?.toString() ?? 'browser',
        compositionId: payload['compositionId']?.toString(),
        batchId: payload['batchId']?.toString(),
        batchTotal: payload['batchTotal'] is int
            ? payload['batchTotal'] as int
            : int.tryParse(payload['batchTotal']?.toString() ?? ''),
        chunkSize: chunkSize,
        totalChunks: totalChunks,
      ),
    );

    final incoming = _incomingFiles[transferId]!;
    socket.add(
      jsonEncode({
        'type': 'file_resume',
        'transferId': transferId,
        'nextChunk': incoming.contiguousCount(),
      }),
    );
  }

  void _handleFileResume(Map<String, dynamic> payload) {
    final socket = _socket;
    final transferId = payload['transferId']?.toString();
    final nextChunk = payload['nextChunk'] is int
        ? payload['nextChunk'] as int
        : int.tryParse(payload['nextChunk']?.toString() ?? '');

    if (socket == null || transferId == null || nextChunk == null) {
      return;
    }

    final outgoing = _outgoingFiles[transferId];
    if (outgoing == null) {
      return;
    }

    onFileProgress(
      transferId,
      outgoing.totalChunks == 0
          ? 0
          : (nextChunk / outgoing.totalChunks).clamp(0, 1).toDouble(),
    );

    outgoing.nextChunk = nextChunk;
    _scheduleChunkPump(socket, outgoing);
  }

  void _handleFileChunk(Map<String, dynamic> payload) {
    final socket = _socket;
    final transferId = payload['transferId']?.toString();
    final chunkIndex = payload['chunkIndex'] is int
        ? payload['chunkIndex'] as int
        : int.tryParse(payload['chunkIndex']?.toString() ?? '');
    final chunk = payload['chunk']?.toString();

    if (socket == null ||
        transferId == null ||
        chunkIndex == null ||
        chunk == null) {
      return;
    }

    final incoming = _incomingFiles[transferId];
    if (incoming == null ||
        chunkIndex < 0 ||
        chunkIndex >= incoming.totalChunks) {
      return;
    }

    final decodedChunk = base64Decode(chunk);
    if (incoming.chunks[chunkIndex] != null) {
      return;
    }

    incoming.chunks[chunkIndex] = decodedChunk;
    incoming.receivedBytes += decodedChunk.length;
    final progress = incoming.size == 0
        ? 0
        : incoming.receivedBytes / incoming.size;
    onFileProgress(transferId, progress.clamp(0, 1).toDouble());
  }

  void _handleFileComplete(Map<String, dynamic> payload) {
    final socket = _socket;
    final transferId = payload['transferId']?.toString();
    if (socket == null || transferId == null) {
      return;
    }

    final incoming = _incomingFiles[transferId];
    if (incoming == null) {
      return;
    }

    if (!incoming.isComplete) {
      socket.add(
        jsonEncode({
          'type': 'file_resume',
          'transferId': transferId,
          'nextChunk': incoming.contiguousCount(),
        }),
      );
      return;
    }

    final merged = BytesBuilder(copy: false);
    for (final chunk in incoming.chunks) {
      if (chunk != null) {
        merged.add(chunk);
      }
    }

    _incomingFiles.remove(transferId);
    socket.add(jsonEncode({'type': 'file_received', 'transferId': transferId}));

    onFileReceived(
      DirectFilePayload(
        transferId: incoming.transferId,
        name: incoming.name,
        mimeType: incoming.mimeType,
        size: incoming.size,
        bytes: merged.takeBytes(),
        sender: incoming.sender,
        compositionId: incoming.compositionId,
        batchId: incoming.batchId,
        batchTotal: incoming.batchTotal,
      ),
    );
  }

  void _handleFileReceived(Map<String, dynamic> payload) {
    final transferId = payload['transferId']?.toString();
    if (transferId == null) {
      return;
    }

    final outgoing = _outgoingFiles.remove(transferId);
    if (outgoing == null) {
      return;
    }

    onFileProgress(transferId, 1);
    onFileDelivered(transferId);
  }

  void _handleFileCancel(Map<String, dynamic> payload) {
    final transferId = payload['transferId']?.toString();
    if (transferId == null) {
      return;
    }

    _outgoingFiles.remove(transferId);
    _incomingFiles.remove(transferId);
  }

  void _sendFileOffer(WebSocket socket, _OutgoingFile outgoing) {
    socket.add(
      jsonEncode({
        'type': 'file_offer',
        'transferId': outgoing.transferId,
        'sender': 'phone',
        'compositionId': outgoing.compositionId,
        'batchId': outgoing.batchId,
        'batchTotal': outgoing.batchTotal,
        'name': outgoing.name,
        'mimeType': outgoing.mimeType,
        'size': outgoing.bytes.length,
        'chunkSize': outgoing.chunkSize,
        'totalChunks': outgoing.totalChunks,
      }),
    );
  }

  void _scheduleChunkPump(WebSocket socket, _OutgoingFile outgoing) {
    if (outgoing.isSending) {
      return;
    }

    outgoing.isSending = true;
    unawaited(_pumpFileChunks(socket, outgoing.transferId));
  }

  Future<void> _pumpFileChunks(WebSocket socket, String transferId) async {
    final outgoing = _outgoingFiles[transferId];
    if (outgoing == null) {
      return;
    }

    if (_socket == null || !identical(_socket, socket)) {
      outgoing.isSending = false;
      return;
    }

    const chunksPerTick = 2;

    if (outgoing.nextChunk >= outgoing.totalChunks) {
      outgoing.isSending = false;
      socket.add(
        jsonEncode({
          'type': 'file_complete',
          'transferId': outgoing.transferId,
        }),
      );
      return;
    }

    final endChunk = outgoing.nextChunk + chunksPerTick > outgoing.totalChunks
        ? outgoing.totalChunks
        : outgoing.nextChunk + chunksPerTick;

    for (
      var chunkIndex = outgoing.nextChunk;
      chunkIndex < endChunk;
      chunkIndex += 1
    ) {
      if (!_outgoingFiles.containsKey(transferId)) {
        return;
      }

      final start = chunkIndex * outgoing.chunkSize;
      final end = (start + outgoing.chunkSize > outgoing.bytes.length)
          ? outgoing.bytes.length
          : start + outgoing.chunkSize;
      final chunk = outgoing.bytes.sublist(start, end);
      socket.add(
        _encodeBinaryChunkFrame(outgoing.transferId, chunkIndex, chunk),
      );
      outgoing.nextChunk = chunkIndex + 1;
      onFileProgress(
        transferId,
        outgoing.totalChunks == 0
            ? 0
            : (outgoing.nextChunk / outgoing.totalChunks)
                  .clamp(0, 1)
                  .toDouble(),
      );
    }

    if (!_outgoingFiles.containsKey(transferId)) {
      return;
    }

    outgoing.isSending = false;

    if (outgoing.nextChunk >= outgoing.totalChunks) {
      socket.add(
        jsonEncode({
          'type': 'file_complete',
          'transferId': outgoing.transferId,
        }),
      );
      return;
    }

    await Future<void>.delayed(_chunkPumpDelay);
    if (_socket == null || !identical(_socket, socket)) {
      return;
    }
    _scheduleChunkPump(socket, outgoing);
  }

  void _handleBinaryChunk(Uint8List frame) {
    final payload = _decodeBinaryChunkFrame(frame);
    if (payload == null) {
      return;
    }

    final incoming = _incomingFiles[payload.transferId];
    if (incoming == null ||
        payload.chunkIndex < 0 ||
        payload.chunkIndex >= incoming.totalChunks ||
        incoming.chunks[payload.chunkIndex] != null) {
      return;
    }

    incoming.chunks[payload.chunkIndex] = payload.chunk;
    incoming.receivedBytes += payload.chunk.length;
    final progress = incoming.size == 0
        ? 0
        : incoming.receivedBytes / incoming.size;
    onFileProgress(payload.transferId, progress.clamp(0, 1).toDouble());
  }

  void sendPhoneMessage(String text, {String? compositionId}) {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.add(
      jsonEncode({
        'type': 'message',
        'sender': 'phone',
        'text': text,
        'compositionId': compositionId,
      }),
    );
  }

  void sendPhonePeerMeta({
    required String name,
    required String address,
    String? deviceInfo,
  }) {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.add(
      jsonEncode({
        'type': 'peer_meta',
        'sender': 'phone',
        'role': 'phone',
        'name': name,
        'address': address,
        if (deviceInfo != null && deviceInfo.trim().isNotEmpty)
          'deviceInfo': deviceInfo.trim(),
      }),
    );
  }

  void sendDisconnectNotice() {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.add(jsonEncode({'type': 'disconnect', 'sender': 'phone'}));
  }

  void sendPhoneFile({
    required String transferId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    String? compositionId,
    String? batchId,
    int? batchTotal,
  }) {
    const chunkSize = 128 * 1024;
    final outgoing = _OutgoingFile(
      transferId: transferId,
      name: name,
      mimeType: mimeType,
      bytes: bytes,
      compositionId: compositionId,
      batchId: batchId,
      batchTotal: batchTotal,
      chunkSize: chunkSize,
    );
    _outgoingFiles[transferId] = outgoing;

    final socket = _socket;
    if (socket == null) {
      return;
    }

    _sendFileOffer(socket, outgoing);
  }

  Future<void> stop() async {
    _isStopping = true;
    await _socket?.close();
    _socket = null;
    await _server?.close(force: true);
    _server = null;
    onStatusChanged('Direct server offline');
  }
}

class _BinaryChunkPayload {
  const _BinaryChunkPayload({
    required this.transferId,
    required this.chunkIndex,
    required this.chunk,
  });

  final String transferId;
  final int chunkIndex;
  final Uint8List chunk;
}

Uint8List _encodeBinaryChunkFrame(
  String transferId,
  int chunkIndex,
  Uint8List chunk,
) {
  final transferIdBytes = utf8.encode(transferId);
  final headerLength = 7 + transferIdBytes.length;
  final frame = Uint8List(headerLength + chunk.length);
  final view = ByteData.sublistView(frame);

  view.setUint8(0, _binaryFileChunkFrame);
  view.setUint16(1, transferIdBytes.length);
  view.setUint32(3, chunkIndex);
  frame.setRange(7, headerLength, transferIdBytes);
  frame.setRange(headerLength, frame.length, chunk);
  return frame;
}

_BinaryChunkPayload? _decodeBinaryChunkFrame(Uint8List frame) {
  if (frame.length < 7 || frame[0] != _binaryFileChunkFrame) {
    return null;
  }

  final view = ByteData.sublistView(frame);
  final transferIdLength = view.getUint16(1);
  final headerLength = 7 + transferIdLength;
  if (frame.length < headerLength) {
    return null;
  }

  final transferId = utf8.decode(frame.sublist(7, headerLength));
  return _BinaryChunkPayload(
    transferId: transferId,
    chunkIndex: view.getUint32(3),
    chunk: frame.sublist(headerLength),
  );
}
