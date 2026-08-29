import 'package:flutter/material.dart';

import '../screen_models.dart';

/// Renderiza as ações de uma tela `SELECAO`.
class SelectionScreenView extends StatelessWidget {
  const SelectionScreenView({
    required this.screen,
    required this.onSelected,
    super.key,
  });

  final SelectionScreen screen;
  final Future<void> Function(ScreenAction action) onSelected;

  @override
  Widget build(BuildContext context) {
    if (screen.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma opção disponível.'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: screen.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final action = screen.items[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            minTileHeight: 64,
            title: Text(action.text),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelected(action),
          ),
        );
      },
    );
  }
}
