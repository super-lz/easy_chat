import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../components/common_widgets.dart';
import '../../provider/chat_session_provider.dart';
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
    final provider = context.read<ChatSessionProvider>();
    provider.pairingController.text = value;
    _apply(provider);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionProvider>();

    return EasyChatPageScaffold(
      bottomBar: BottomActionBar(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _apply(provider),
            child: const Text('继续'),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: '扫码连接',
            subtitle: '读取网页二维码',
            leading: AppBackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(RoutePaths.home);
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GlassSurface(
                    radius: 30,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '将网页上的二维码放入取景框内，识别成功后会自动填入配对链接。',
                          style: TextStyle(
                            color: Color(0xFF667589),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 340,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: const Color(0xFF1A2330),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                MobileScanner(onDetect: _handleBarcode),
                                IgnorePointer(
                                  child: Container(
                                    width: 244,
                                    height: 244,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        width: 1.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: '配对链接',
                    controller: provider.pairingController,
                    minLines: 3,
                    maxLines: 5,
                    hintText:
                        'easychat://pair?sessionId=...&challenge=...&serverUrl=...',
                    errorText: provider.registrationError,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _apply(ChatSessionProvider provider) {
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
