import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

class NetworkTools {
  static Future<String?> detectBestLocalIp({String? preferredPeerIp}) async {
    final wifiIp = await _detectWifiIp();
    if (wifiIp != null) {
      return wifiIp;
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      String? bestCandidate;
      var bestScore = -1;
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final value = address.address;
          if (!isUsableIpv4(value)) {
            continue;
          }

          final score = scoreIpCandidate(
            candidateIp: value,
            preferredPeerIp: preferredPeerIp,
          );
          if (score > bestScore) {
            bestScore = score;
            bestCandidate = value;
          }
        }
      }

      return bestCandidate;
    } catch (_) {
      return null;
    }
  }

  static bool isUsableIpv4(String value) {
    final address = InternetAddress.tryParse(value);
    return address != null &&
        address.type == InternetAddressType.IPv4 &&
        !address.isLoopback;
  }

  static bool isPrivateLanIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) {
      return false;
    }

    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  static String? extractHostIp(String serverUrl) {
    final uri = Uri.tryParse(serverUrl);
    final host = uri?.host;
    if (host == null || !isUsableIpv4(host)) {
      return null;
    }
    return host;
  }

  static int scoreIpCandidate({
    required String candidateIp,
    String? preferredPeerIp,
  }) {
    var score = 0;

    if (isPrivateLanIpv4(candidateIp)) {
      score += 10;
    }

    if (preferredPeerIp == null) {
      return score;
    }

    final candidateParts = candidateIp.split('.');
    final peerParts = preferredPeerIp.split('.');
    if (candidateParts.length != 4 || peerParts.length != 4) {
      return score;
    }

    if (candidateParts[0] == peerParts[0]) {
      score += 10;
    }
    if (candidateParts[0] == peerParts[0] &&
        candidateParts[1] == peerParts[1]) {
      score += 20;
    }
    if (candidateParts[0] == peerParts[0] &&
        candidateParts[1] == peerParts[1] &&
        candidateParts[2] == peerParts[2]) {
      score += 40;
    }

    return score;
  }

  static String? buildSubnetWarning(String? serverUrl, String localIp) {
    final serverHost = Uri.tryParse(serverUrl ?? '')?.host;
    final localParts = localIp.split('.');
    final serverParts = (serverHost ?? '').split('.');

    if (localParts.length != 4 || serverParts.length != 4) {
      return null;
    }

    if (localParts[0] == serverParts[0] &&
        localParts[1] == serverParts[1] &&
        localParts[2] == serverParts[2]) {
      return null;
    }

    return '当前手机 IP 与电脑地址不在同一网段，可能无法直连。';
  }

  static Future<String?> _detectWifiIp() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (isUsableIpv4(wifiIp ?? '')) {
        return wifiIp;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
