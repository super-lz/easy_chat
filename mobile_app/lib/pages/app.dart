import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../common/app_constants.dart';
import '../provider/chat_session_provider.dart';
import '../route/app_router.dart';
import '../route/route_paths.dart';
import '../service/chat_history_store.dart';
import '../theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppShell();
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  late final ChatHistoryStore _chatHistoryStore;
  late final ChatSessionProvider _provider;
  late final _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatHistoryStore = ChatHistoryStore();
    _provider = ChatSessionProvider(chatHistoryStore: _chatHistoryStore);
    unawaited(_bootstrapConnection());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_provider.restoreServerOnForeground());
    }
  }

  Future<void> _bootstrapConnection() async {
    final restored = await _provider.restoreConnectionIfNeeded();
    if (!mounted) return;
    if (restored) {
      _router.go(RoutePaths.chat);
      return;
    }
    _router.go(RoutePaths.home);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _globalProviders,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: buildEasyChatTheme(),
        routerConfig: _router,
      ),
    );
  }

  List<SingleChildWidget> get _globalProviders => [
    Provider<ChatHistoryStore>.value(value: _chatHistoryStore),
    ChangeNotifierProvider<ChatSessionProvider>.value(value: _provider),
  ];
}
