import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../route/route_paths.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EasyChat',
                style: TextStyle(
                  color: Color(0xFF151B26),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '扫码连接',
                style: TextStyle(
                  color: Color(0xFF151B26),
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  height: 1.02,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '扫描网页上的二维码，在手机和电脑之间建立本地直连',
                style: TextStyle(
                  color: Color(0xFF8B95A1),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(RoutePaths.scan),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF169AF3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    '扫码',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
