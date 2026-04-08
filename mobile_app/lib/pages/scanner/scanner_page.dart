import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../provider/chat_session_provider.dart';
import '../../route/route_paths.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _hasScanned = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_hasScanned || !mounted) return;

    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    _hasScanned = true;
    await _scannerController.stop();
    if (!mounted) return;
    final provider = context.read<ChatSessionProvider>();
    provider.pairingController.text = value;
    _apply(provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScannerHeader(
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go(RoutePaths.home);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '扫码连接',
                style: TextStyle(
                  color: Color(0xFF151B26),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '将网页二维码放入框内',
                style: TextStyle(
                  color: Color(0xFF8B95A1),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1115),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _handleBarcode,
                        ),
                        IgnorePointer(
                          child: FractionallySizedBox(
                            widthFactor: 0.68,
                            heightFactor: 0.68,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _apply(ChatSessionProvider provider) async {
    await _scannerController.stop();
    if (!mounted) return;
    await provider.ensureLocalDeviceNameLoaded();
    if (!mounted) return;
    final isValid = provider.applyPairingInput();
    if (!mounted) return;
    if (isValid) {
      await context.push(RoutePaths.confirm);
      return;
    }
    _hasScanned = false;
    await _scannerController.start();
  }
}

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(
            minimumSize: const Size(42, 42),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF314054),
            elevation: 0,
            side: BorderSide.none,
          ),
        ),
      ],
    );
  }
}
