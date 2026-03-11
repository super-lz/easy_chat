import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../provider/chat_session_pprovider.dart';
import '../../route/route_paths.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _hasScanned = false;

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;

    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    _hasScanned = true;
    final provider = context.read<ChatSessionPProvider>();
    provider.pairingController.text = value;
    _apply(provider);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionPProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go(RoutePaths.home);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Spacer(),
                  const Text('扫码连接'),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          color: const Color(0xFF131313),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              MobileScanner(onDetect: _handleBarcode),
                              IgnorePointer(
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white70,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: provider.pairingController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: '配对链接',
                          hintText:
                              'easychat://pair?sessionId=...&challenge=...&serverUrl=...',
                          errorText: provider.registrationError,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFFDEDAD2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFFDEDAD2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _apply(provider),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D1D1F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text('继续'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _apply(ChatSessionPProvider provider) {
    final isValid = provider.applyPairingInput();
    if (!mounted) return;
    if (isValid) {
      context.push(RoutePaths.confirm);
      return;
    }
    if (GoRouterState.of(context).uri.path != RoutePaths.scan) {
      context.go(RoutePaths.scan);
    }
  }
}
