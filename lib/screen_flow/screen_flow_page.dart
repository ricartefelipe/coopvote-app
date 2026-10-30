import 'package:flutter/material.dart';

import 'screen_api.dart';
import 'screen_controller.dart';
import 'screen_models.dart';
import 'widgets/form_screen_view.dart';
import 'widgets/selection_screen_view.dart';

/// Hospeda o fluxo server-driven e seus estados de carregamento e erro.
class ScreenFlowPage extends StatefulWidget {
  const ScreenFlowPage({
    required this.entryUri,
    required this.screenApi,
    this.onSessionExpired,
    this.onLogout,
    super.key,
  });

  final Uri entryUri;
  final ScreenApi screenApi;
  final Future<void> Function()? onSessionExpired;
  final Future<void> Function()? onLogout;

  @override
  State<ScreenFlowPage> createState() => _ScreenFlowPageState();
}

class _ScreenFlowPageState extends State<ScreenFlowPage> {
  late final ScreenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScreenController(
      widget.screenApi,
      widget.entryUri,
      onSessionExpired: widget.onSessionExpired,
    );
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.screenApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final screen = _controller.screen;
        return Scaffold(
          appBar: AppBar(
            title: Text(screen?.title ?? 'CoopVote'),
            centerTitle: true,
            actions: [
              if (widget.onLogout != null)
                IconButton(
                  key: const ValueKey('logout'),
                  tooltip: 'Sair',
                  icon: const Icon(Icons.logout),
                  onPressed: widget.onLogout,
                ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    if (screen != null && _controller.errorMessage != null)
                      _ErrorBanner(
                        message: _controller.errorMessage!,
                        onDismiss: _controller.clearError,
                        onRetry: _controller.retry,
                        retryLabel:
                            _controller.voteOutcome == VoteOutcome.pending
                            ? 'Conferir recibo'
                            : 'Tentar novamente',
                      ),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: _controller.loading,
                        child: _content(screen),
                      ),
                    ),
                  ],
                ),
              ),
              if (_controller.loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(semanticsLabel: 'Carregando'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _content(AppScreen? screen) {
    if (screen == null) {
      if (_controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _InitialError(
        message: _controller.errorMessage,
        onRetry: _controller.retry,
      );
    }
    return switch (screen) {
      FormScreen() => FormScreenView(
        key: ValueKey(screen),
        screen: screen,
        onSubmit: (action, values) =>
            _controller.submit(action, inputValues: values),
      ),
      SelectionScreen() => SelectionScreenView(
        screen: screen,
        onSelected: _controller.submit,
      ),
    };
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: 'Fechar mensagem',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('retry'),
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  const _InitialError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              message ?? 'Não foi possível carregar a tela inicial.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
