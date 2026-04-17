import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/chat/chat_page.dart';
import '../pages/confirm/confirm_page.dart';
import '../pages/history/history_conversation_page.dart';
import '../pages/history/history_page.dart';
import '../pages/home/home_page.dart';
import '../pages/scanner/scanner_page.dart';
import 'route_paths.dart';

GoRouter createAppRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: RoutePaths.scan,
        builder: (context, state) => const ScannerPage(),
      ),
      GoRoute(
        path: RoutePaths.confirm,
        builder: (context, state) => const ConfirmPage(),
      ),
      GoRoute(
        path: RoutePaths.chat,
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: RoutePaths.history,
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '${RoutePaths.history}/:conversationId',
        builder: (context, state) => HistoryConversationPage(
          conversationId: state.pathParameters['conversationId'] ?? '',
        ),
      ),
    ],
  );
}
