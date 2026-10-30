import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/login_page.dart';
import 'config/app_config.dart';
import 'screen_flow/screen_api.dart';
import 'screen_flow/screen_flow_page.dart';
import 'session/api_origin.dart';
import 'session/auth_api.dart';
import 'session/session_controller.dart';
import 'session/session_store.dart';

/// Raiz visual do cliente CoopVote: sem sessão válida mostra o login; com ela, o fluxo de telas.
class CoopVoteApp extends StatefulWidget {
  const CoopVoteApp({
    required this.entryUri,
    this.sessionController,
    this.screenApiFactory,
    this.allowInsecureHttp = AppConfig.allowInsecureHttp,
    super.key,
  });

  final Uri entryUri;
  final SessionController? sessionController;
  final ScreenApi Function(ApiOrigin origin, String? Function() token)?
  screenApiFactory;
  final bool allowInsecureHttp;

  @override
  State<CoopVoteApp> createState() => _CoopVoteAppState();
}

class _CoopVoteAppState extends State<CoopVoteApp> {
  late final ApiOrigin _origin;
  late final SessionController _session;
  late final bool _ownsSession;
  AuthApi? _authApi;

  @override
  void initState() {
    super.initState();
    _origin = ApiOrigin(
      widget.entryUri,
      allowInsecureHttp: widget.allowInsecureHttp,
    );
    _ownsSession = widget.sessionController == null;
    if (_ownsSession) {
      _authApi = AuthApi(_origin);
      _session = SessionController(
        _authApi!,
        kIsWeb ? InMemorySessionStore() : SecureSessionStore(),
      );
    } else {
      _session = widget.sessionController!;
    }
    _session.restore();
  }

  @override
  void dispose() {
    if (_ownsSession) {
      _session.dispose();
      _authApi?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF146C43);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CoopVote',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          if (!_session.restored) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = _session.session;
          if (!_session.signedIn || session == null) {
            return LoginPage(session: _session);
          }
          return ScreenFlowPage(
            key: ValueKey(session.accessToken),
            entryUri: widget.entryUri,
            screenApi:
                widget.screenApiFactory?.call(
                  _origin,
                  () => _session.session?.accessToken,
                ) ??
                ScreenApi(_origin, token: () => _session.session?.accessToken),
            onSessionExpired: _session.expire,
            onLogout: _session.logout,
          );
        },
      ),
    );
  }
}
