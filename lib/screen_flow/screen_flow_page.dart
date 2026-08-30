import 'package:flutter/material.dart';

import 'screen_api.dart';
import 'screen_controller.dart';
import 'screen_models.dart';
import 'widgets/form_screen_view.dart';
import 'widgets/selection_screen_view.dart';

/// Hospeda o fluxo server-driven e seus estados de carregamento e erro.
class ScreenFlowPage extends StatefulWidget {
  const ScreenFlowPage({required this.entryUri, this.screenApi, super.key});

  final Uri entryUri;
  final ScreenApi? screenApi;

  @override
  State<ScreenFlowPage> createState() => _ScreenFlowPageState();
}

class _ScreenFlowPageState extends State<ScreenFlowPage> {
  late final bool _ownsApi;
  late final ScreenApi _api;
  late final ScreenController _controller;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.screenApi == null;
    _api = widget.screenApi ?? ScreenApi();
    _controller = ScreenController(_api, widget.entryUri);
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsApi) {
      _api.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final screen = _controller.screen;

        return PopScope(
          canPop: !_controller.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _controller.goBack();
            }
          },
          child: Scaffold(
          appBar: AppBar(
            leading: _controller.canGoBack
                ? IconButton(
                    key: const ValueKey('back-app-bar'),
                    tooltip: 'Voltar',
                    onPressed: _controller.goBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            title: Text(screen?.title ?? 'CoopVote'),
            centerTitle: true,
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
                      ),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: _controller.loading,
                        child: _content(screen),
                      ),
                    ),
                    if (_controller.canGoBack)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            key: const ValueKey('back-button'),
                            onPressed: _controller.goBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Voltar'),
                          ),
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
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
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
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
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
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
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
