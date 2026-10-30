/// Tela server-driven reconhecida pelo cliente.
sealed class AppScreen {
  const AppScreen({required this.title});

  final String title;

  factory AppScreen.fromJson(Object? value) {
    final json = _object(value, 'resposta');
    return switch (_requiredString(json, 'tipo')) {
      'FORMULARIO' => FormScreen.fromJson(json),
      'SELECAO' => SelectionScreen.fromJson(json),
      final type => throw ScreenProtocolException(
        'Tipo de tela não suportado: $type.',
      ),
    };
  }
}

/// Tela composta por itens e até duas ações.
final class FormScreen extends AppScreen {
  const FormScreen({
    required super.title,
    required this.items,
    required this.okButton,
    this.cancelButton,
  });

  final List<FormItem> items;
  final ScreenAction okButton;
  final ScreenAction? cancelButton;

  factory FormScreen.fromJson(Map<String, Object?> json) {
    final items = _requiredList(
      json,
      'itens',
    ).map(FormItem.fromJson).toList(growable: false);
    final inputIds = items.whereType<InputFormItem>().map((item) => item.id);
    if (inputIds.toSet().length != inputIds.length) {
      throw const ScreenProtocolException(
        'A tela contém campos de entrada com identificadores duplicados.',
      );
    }

    return FormScreen(
      title: _requiredString(json, 'titulo'),
      items: items,
      okButton: ScreenAction.fromJson(json['botaoOk'], 'botaoOk'),
      cancelButton: json['botaoCancelar'] == null
          ? null
          : ScreenAction.fromJson(json['botaoCancelar'], 'botaoCancelar'),
    );
  }
}

/// Tela composta por uma lista de ações.
final class SelectionScreen extends AppScreen {
  const SelectionScreen({required super.title, required this.items});

  final List<ScreenAction> items;

  factory SelectionScreen.fromJson(Map<String, Object?> json) {
    return SelectionScreen(
      title: _requiredString(json, 'titulo'),
      items: _requiredList(json, 'itens')
          .asMap()
          .entries
          .map(
            (entry) =>
                ScreenAction.fromJson(entry.value, 'itens[${entry.key}]'),
          )
          .toList(growable: false),
    );
  }
}

/// Componente renderizável dentro de um formulário.
sealed class FormItem {
  const FormItem();

  factory FormItem.fromJson(Object? value) {
    final json = _object(value, 'item de formulário');
    return switch (_requiredString(json, 'tipo')) {
      'TEXTO' => TextFormItem(text: _requiredString(json, 'texto')),
      'INPUT_TEXTO' => TextInputFormItem(
        id: _requiredString(json, 'id'),
        title: _requiredString(json, 'titulo'),
        initialValue: _optionalString(json['valor'], 'valor'),
      ),
      'INPUT_NUMERO' => NumberInputFormItem(
        id: _requiredString(json, 'id'),
        title: _requiredString(json, 'titulo'),
        initialValue: _optionalNumber(json['valor'], 'valor'),
      ),
      'INPUT_DATA' => DateInputFormItem(
        id: _requiredString(json, 'id'),
        title: _requiredString(json, 'titulo'),
        initialValue: _optionalString(json['valor'], 'valor'),
      ),
      final type => throw ScreenProtocolException(
        'Tipo de item não suportado: $type.',
      ),
    };
  }
}

/// Texto informativo sem entrada do usuário.
final class TextFormItem extends FormItem {
  const TextFormItem({required this.text});

  final String text;
}

/// Base dos componentes que enviam valores identificados ao callback.
sealed class InputFormItem extends FormItem {
  const InputFormItem({required this.id, required this.title});

  final String id;
  final String title;
}

/// Entrada textual.
final class TextInputFormItem extends InputFormItem {
  const TextInputFormItem({
    required super.id,
    required super.title,
    this.initialValue,
  });

  final String? initialValue;
}

/// Entrada numérica.
final class NumberInputFormItem extends InputFormItem {
  const NumberInputFormItem({
    required super.id,
    required super.title,
    this.initialValue,
  });

  final num? initialValue;
}

/// Entrada de data no formato `dd/MM/yyyy`.
final class DateInputFormItem extends InputFormItem {
  const DateInputFormItem({
    required super.id,
    required super.title,
    this.initialValue,
  });

  final String? initialValue;
}

/// Ação que descreve o rótulo, o callback e seu corpo opcional.
final class ScreenAction {
  ScreenAction({
    required this.text,
    required this.url,
    Map<String, Object?>? body,
  }) : body = body == null ? null : Map.unmodifiable(body);

  final String text;
  final Uri url;
  final Map<String, Object?>? body;

  factory ScreenAction.fromJson(Object? value, String field) {
    final json = _object(value, field);
    final rawUrl = _requiredString(json, 'url');
    final url = Uri.tryParse(rawUrl);
    if (url == null || !url.hasScheme || url.host.isEmpty) {
      throw ScreenProtocolException('$field.url deve ser uma URL absoluta.');
    }

    final rawBody = json['body'];
    return ScreenAction(
      text: _requiredString(json, 'texto'),
      url: url,
      body: rawBody == null ? null : _object(rawBody, '$field.body'),
    );
  }

  /// Combina o corpo fixo da ação com os valores preenchidos na tela.
  Map<String, Object?>? payloadWith(Map<String, Object?> inputValues) {
    if (body == null && inputValues.isEmpty) {
      return null;
    }
    return <String, Object?>{...?body, ...inputValues};
  }
}

/// Limites do protocolo: uma tela não cresce sem teto nem carrega textos enormes.
abstract final class ProtocolLimits {
  static const int maxItems = 200;
  static const int maxTextLength = 2000;
}

/// Indica que uma resposta não respeita o protocolo suportado.
final class ScreenProtocolException implements Exception {
  const ScreenProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) {
    throw ScreenProtocolException('$field deve ser um objeto JSON.');
  }
  if (value.keys.any((key) => key is! String)) {
    throw ScreenProtocolException('$field contém uma chave inválida.');
  }
  return value.cast<String, Object?>();
}

List<Object?> _requiredList(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! List) {
    throw ScreenProtocolException('$field deve ser uma lista.');
  }
  if (value.length > ProtocolLimits.maxItems) {
    throw ScreenProtocolException(
      '$field excede o máximo de ${ProtocolLimits.maxItems} itens.',
    );
  }
  return value.cast<Object?>();
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw ScreenProtocolException('$field deve ser um texto não vazio.');
  }
  return _bounded(value, field);
}

String _bounded(String value, String field) {
  if (value.length > ProtocolLimits.maxTextLength) {
    throw ScreenProtocolException(
      '$field excede o máximo de ${ProtocolLimits.maxTextLength} caracteres.',
    );
  }
  return value;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ScreenProtocolException('$field deve ser um texto.');
  }
  return _bounded(value, field);
}

num? _optionalNumber(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw ScreenProtocolException('$field deve ser um número.');
  }
  return value;
}
