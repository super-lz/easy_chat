import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mobile_app/utils/app_error_formatter.dart';

void main() {
  group('AppErrorFormatter', () {
    test('keeps readable exception messages', () {
      expect(AppErrorFormatter.message(Exception('保存失败')), '保存失败');
    });

    test('formats network route errors in network context', () {
      final message = AppErrorFormatter.message(
        SocketException('No route to host'),
        assumeNetworkContext: true,
        uri: Uri.parse('http://192.168.31.8:8080'),
        networkHint: '当前手机 IP 与电脑地址不在同一网段，可能无法直连。',
      );

      expect(message, contains('当前网络无法访问电脑'));
      expect(message, contains('同一网段'));
    });

    test('does not force network wording outside network context', () {
      expect(
        AppErrorFormatter.message(
          SocketException('Connection refused'),
          fallback: '保存失败，请稍后重试',
        ),
        '保存失败，请稍后重试',
      );
    });

    test('formats client exceptions in network context', () {
      final error = ClientException(
        'Connection refused',
        Uri.parse('http://192.168.31.8:8080'),
      );

      expect(
        AppErrorFormatter.message(
          error,
          assumeNetworkContext: true,
          uri: error.uri,
        ),
        contains('拒绝了连接'),
      );
    });
  });
}
