import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;

class AppErrorFormatter {
  const AppErrorFormatter._();

  static String message(
    Object error, {
    String fallback = '操作失败，请稍后重试',
    bool assumeNetworkContext = false,
    Uri? uri,
    String? networkHint,
  }) {
    if (assumeNetworkContext && isNetworkError(error)) {
      return _networkMessage(error, uri: uri, networkHint: networkHint);
    }

    final readable = _extractReadableMessage(error);
    if (readable != null) {
      return readable;
    }

    return fallback;
  }

  static bool isNetworkError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is HandshakeException ||
        error is ClientException) {
      return true;
    }

    final lower = _clean(error.toString()).toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no route to host') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('timed out') ||
        lower.contains('handshakeexception');
  }

  static String _networkMessage(Object error, {Uri? uri, String? networkHint}) {
    final lower = _clean(error.toString()).toLowerCase();
    final host = uri?.host.trim();
    final target = host == null || host.isEmpty ? '电脑' : '电脑（$host）';

    late final String base;
    if (lower.contains('failed host lookup')) {
      base = '无法找到$target，请确认二维码仍然有效。';
    } else if (lower.contains('connection refused')) {
      base = '$target拒绝了连接，请确认电脑上的网页仍保持打开。';
    } else if (lower.contains('no route to host') ||
        lower.contains('network is unreachable')) {
      base = '当前网络无法访问$target。';
    } else if (lower.contains('timed out')) {
      base = '连接$target超时。';
    } else if (lower.contains('connection reset')) {
      base = '与$target的连接已中断。';
    } else {
      base = '无法连接到$target。';
    }

    final hint = networkHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      return '$base\n$hint 请确认手机和电脑在同一 Wi‑Fi 下后重试。';
    }

    return '$base 请确认手机和电脑在同一 Wi‑Fi 下，电脑页面保持打开，并允许局域网访问后重试。';
  }

  static String? _extractReadableMessage(Object error) {
    final message = _clean(error.toString());
    if (message.isEmpty || !_looksReadable(message)) {
      return null;
    }
    return message;
  }

  static bool _looksReadable(String message) {
    final lower = message.toLowerCase();
    return !lower.contains('socketexception') &&
        !lower.contains('clientexception') &&
        !lower.contains('os error') &&
        !lower.contains('stack trace');
  }

  static String _clean(String value) {
    return value.trim().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
  }
}
