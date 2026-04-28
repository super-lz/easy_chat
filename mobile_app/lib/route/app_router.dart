import 'package:flutter/cupertino.dart';
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
        pageBuilder: (context, state) =>
            _cupertinoTransitionPage(state, const HomePage()),
        routes: [
          GoRoute(
            path: _relativePath(RoutePaths.scan),
            pageBuilder: (context, state) =>
                _cupertinoTransitionPage(state, const ScannerPage()),
          ),
          GoRoute(
            path: _relativePath(RoutePaths.confirm),
            pageBuilder: (context, state) =>
                _cupertinoTransitionPage(state, const ConfirmPage()),
          ),
          GoRoute(
            path: _relativePath(RoutePaths.chat),
            pageBuilder: (context, state) =>
                _cupertinoTransitionPage(state, const ChatPage()),
          ),
          GoRoute(
            path: _relativePath(RoutePaths.history),
            pageBuilder: (context, state) =>
                _cupertinoTransitionPage(state, const HistoryPage()),
          ),
          GoRoute(
            path: '${_relativePath(RoutePaths.history)}/:conversationId',
            pageBuilder: (context, state) => _cupertinoTransitionPage(
              state,
              HistoryConversationPage(
                conversationId: state.pathParameters['conversationId'] ?? '',
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Page<void> _cupertinoTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: false,
        child: child,
      );
    },
  );
}

String _relativePath(String absolutePath) {
  return absolutePath.startsWith('/')
      ? absolutePath.substring(1)
      : absolutePath;
}
