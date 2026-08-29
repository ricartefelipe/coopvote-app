import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screen_flow/screen_api.dart';
import 'screen_flow/screen_flow_page.dart';

/// Raiz visual do cliente CoopVote.
class CoopVoteApp extends StatelessWidget {
  const CoopVoteApp({required this.entryUri, this.screenApi, super.key});

  final Uri entryUri;
  final ScreenApi? screenApi;

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
      home: ScreenFlowPage(entryUri: entryUri, screenApi: screenApi),
    );
  }
}
