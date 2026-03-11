import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef DirectMessageHandler = void Function(String text);
typedef FileReceivedHandler = void Function(DirectFilePayload file);
typedef FileProgressHandler = void Function(String transferId, double progress);
typedef FileDeliveredHandler = void Function(String transferId);
typedef ServerStatusHandler = void Function(String status);

class DirectFilePayload {
  const DirectFilePayload({
    required this.transferId,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.bytes,
    required this.sender,
    this.batchId,
    this.batchTotal,
  });

  final String transferId;
  final String name;
  final String mimeType;
  final int size;
  final Uint8List bytes;
  final String sender;
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
  final String? batchId;
  final int? batchTotal;
  final int chunkSize;
  final int totalChunks;
  final List<Uint8List?> chunks;

  int contiguousCount() {
    var count = 0;
    while (count < chunks.length && chunks[count] != null) {
      count += 1;
    }
    return count;
  }

  int receivedBytes() {
    return chunks.fold(0, (sum, part) => sum + (part?.length ?? 0));
  }

  bool get isComplete => contiguousCount() == totalChunks;
}

class _OutgoingFile {
  _OutgoingFile({
    required this.transferId,
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.batchId,
    this.batchTotal,
    required this.chunkSize,
  }) : totalChunks = (bytes.length / chunkSize).ceil();

  final String transferId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? batchId;
  final int? batchTotal;
  final int chunkSize;
  final int totalChunks;
}

class LocalChatServer {
  LocalChatServer({
    required this.onBrowserMessage,
    required this.onFileReceived,
    required this.onFileProgress,
    required this.onFileDelivered,
    required this.onStatusChanged,
  });

  DirectMessageHandler onBrowserMessage;
  FileReceivedHandler onFileReceived;
  FileProgressHandler onFileProgress;
  FileDeliveredHandler onFileDelivered;
  ServerStatusHandler onStatusChanged;

  HttpServer? _server;
  WebSocket? _socket;
  String? _token;
  final Map<String, _IncomingFile> _incomingFiles = {};
  final Map<String, _OutgoingFile> _outgoingFiles = {};

  bool get isRunning => _server != null;

  Future<void> start({required int port, required String token}) async {
    await stop();

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
            final payload = jsonDecode(raw as String) as Map<String, dynamic>;
            switch (payload['type']) {
              case 'message':
                final text = payload['text']?.toString().trim() ?? '';
                if (text.isNotEmpty) {
                  onBrowserMessage(text);
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
            onStatusChanged('Waiting for browser reconnect');
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

    _sendChunksFrom(socket, outgoing, nextChunk);
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

    incoming.chunks[chunkIndex] ??= base64Decode(chunk);
    final progress = incoming.size == 0
        ? 0
        : incoming.receivedBytes() / incoming.size;
    onFileProgress(transferId, progress.clamp(0, 1).toDouble());

    socket.add(
      jsonEncode({
        'type': 'file_resume',
        'transferId': transferId,
        'nextChunk': incoming.contiguousCount(),
      }),
    );
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

  void _sendFileOffer(WebSocket socket, _OutgoingFile outgoing) {
    socket.add(
      jsonEncode({
        'type': 'file_offer',
        'transferId': outgoing.transferId,
        'sender': 'phone',
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

  void _sendChunksFrom(
    WebSocket socket,
    _OutgoingFile outgoing,
    int startChunk,
  ) {
    if (startChunk >= outgoing.totalChunks) {
      socket.add(
        jsonEncode({
          'type': 'file_complete',
          'transferId': outgoing.transferId,
        }),
      );
      return;
    }

    for (
      var chunkIndex = startChunk;
      chunkIndex < outgoing.totalChunks;
      chunkIndex += 1
    ) {
      final start = chunkIndex * outgoing.chunkSize;
      final end = (start + outgoing.chunkSize > outgoing.bytes.length)
          ? outgoing.bytes.length
          : start + outgoing.chunkSize;
      final chunk = outgoing.bytes.sublist(start, end);
      socket.add(
        jsonEncode({
          'type': 'file_chunk',
          'transferId': outgoing.transferId,
          'chunkIndex': chunkIndex,
          'chunk': base64Encode(chunk),
        }),
      );
    }

    socket.add(
      jsonEncode({'type': 'file_complete', 'transferId': outgoing.transferId}),
    );
  }

  void sendPhoneMessage(String text) {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.add(
      jsonEncode({'type': 'message', 'sender': 'phone', 'text': text}),
    );
  }

  void sendPhoneFile({
    required String transferId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    String? batchId,
    int? batchTotal,
  }) {
    const chunkSize = 32 * 1024;
    final outgoing = _OutgoingFile(
      transferId: transferId,
      name: name,
      mimeType: mimeType,
      bytes: bytes,
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
    await _socket?.close();
    _socket = null;
    await _server?.close(force: true);
    _server = null;
    onStatusChanged('Direct server offline');
  }
}
