import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../screen_models.dart';

/// Renderiza os componentes e as ações de uma tela `FORMULARIO`.
class FormScreenView extends StatefulWidget {
  const FormScreenView({
    required this.screen,
    required this.onSubmit,
    super.key,
  });

  final FormScreen screen;
  final Future<void> Function(ScreenAction action, Map<String, Object?> values)
  onSubmit;

  @override
  State<FormScreenView> createState() => _FormScreenViewState();
}

class _FormScreenViewState extends State<FormScreenView> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  @override
  void didUpdateWidget(covariant FormScreenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.screen, widget.screen)) {
      _disposeControllers();
      _createControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _createControllers() {
    _controllers = {
      for (final item in widget.screen.items.whereType<InputFormItem>())
        item.id: TextEditingController(text: _initialText(item)),
    };
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
  }

  String _initialText(InputFormItem item) {
    return switch (item) {
      TextInputFormItem() => item.initialValue ?? '',
      NumberInputFormItem() => item.initialValue?.toString() ?? '',
      DateInputFormItem() => item.initialValue ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          for (final item in widget.screen.items) _buildItem(item),
          const SizedBox(height: 12),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildItem(FormItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (item) {
        TextFormItem() => SelectableText(
          item.text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        TextInputFormItem() => TextFormField(
          key: ValueKey('input_${item.id}'),
          controller: _controllers[item.id],
          decoration: InputDecoration(labelText: item.title),
          textInputAction: TextInputAction.next,
        ),
        NumberInputFormItem() => TextFormField(
          key: ValueKey('input_${item.id}'),
          controller: _controllers[item.id],
          decoration: InputDecoration(labelText: item.title),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[\.,]?\d*')),
          ],
          validator: _validateNumber,
          textInputAction: TextInputAction.next,
        ),
        DateInputFormItem() => TextFormField(
          key: ValueKey('input_${item.id}'),
          controller: _controllers[item.id],
          decoration: InputDecoration(
            labelText: item.title,
            hintText: 'dd/mm/aaaa',
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          readOnly: true,
          onTap: () => _selectDate(item),
          validator: _validateDate,
        ),
      },
    );
  }

  Widget _buildActions() {
    final cancelButton = widget.screen.cancelButton;
    if (cancelButton == null) {
      return SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () => _submit(widget.screen.okButton),
          child: Text(widget.screen.okButton.text),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => _submit(cancelButton),
              child: Text(cancelButton.text),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => _submit(widget.screen.okButton),
              child: Text(widget.screen.okButton.text),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(DateInputFormItem item) async {
    final currentValue = _controllers[item.id]?.text;
    DateTime initialDate;
    try {
      initialDate = currentValue == null || currentValue.isEmpty
          ? DateTime.now()
          : _dateFormat.parseStrict(currentValue);
    } on FormatException {
      initialDate = DateTime.now();
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null && mounted) {
      _controllers[item.id]?.text = _dateFormat.format(selectedDate);
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (num.tryParse(value.trim().replaceAll(',', '.')) == null) {
      return 'Informe um número válido.';
    }
    return null;
  }

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      _dateFormat.parseStrict(value.trim());
      return null;
    } on FormatException {
      return 'Informe uma data válida.';
    }
  }

  Future<void> _submit(ScreenAction action) async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await widget.onSubmit(action, _inputValues());
  }

  Map<String, Object?> _inputValues() {
    final values = <String, Object?>{};
    for (final item in widget.screen.items.whereType<InputFormItem>()) {
      final rawValue = _controllers[item.id]?.text.trim() ?? '';
      if (rawValue.isEmpty) {
        continue;
      }

      values[item.id] = switch (item) {
        NumberInputFormItem() => num.parse(rawValue.replaceAll(',', '.')),
        TextInputFormItem() || DateInputFormItem() => rawValue,
      };
    }
    return values;
  }
}
