import 'package:coopvote_app/screen_flow/screen_models.dart';
import 'package:coopvote_app/screen_flow/widgets/form_screen_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('valida e serializa texto, número e data', (tester) async {
    final submissions = <Map<String, Object?>>[];
    final screen = FormScreen(
      title: 'Formulário',
      items: const [
        TextFormItem(text: 'Preencha os dados.'),
        TextInputFormItem(id: 'name', title: 'Nome'),
        NumberInputFormItem(id: 'amount', title: 'Quantidade', initialValue: 2),
        DateInputFormItem(
          id: 'date',
          title: 'Data',
          initialValue: '28/08/2026',
        ),
      ],
      okButton: ScreenAction(
        text: 'Enviar',
        url: Uri.parse('https://api.example.test/send'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormScreenView(
            screen: screen,
            onSubmit: (_, values) async => submissions.add(values),
          ),
        ),
      ),
    );

    expect(find.text('Preencha os dados.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('input_amount')))
          .controller
          ?.text,
      '2',
    );

    await tester.enterText(find.byKey(const ValueKey('input_amount')), '-');
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
    await tester.pump();
    expect(find.text('Informe um número válido.'), findsOneWidget);
    expect(submissions, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('input_name')), '  Ana  ');
    await tester.enterText(find.byKey(const ValueKey('input_amount')), '1,5');
    await tester.tap(find.byKey(const ValueKey('input_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
    await tester.pump();

    expect(submissions, [
      {'name': 'Ana', 'amount': 1.5, 'date': '28/08/2026'},
    ]);
  });

  testWidgets('aciona o botão de cancelamento', (tester) async {
    ScreenAction? selectedAction;
    final cancelAction = ScreenAction(
      text: 'Cancelar',
      url: Uri.parse('https://api.example.test/cancel'),
    );
    final screen = FormScreen(
      title: 'Formulário',
      items: const [],
      okButton: ScreenAction(
        text: 'Salvar',
        url: Uri.parse('https://api.example.test/save'),
      ),
      cancelButton: cancelAction,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormScreenView(
            screen: screen,
            onSubmit: (action, _) async => selectedAction = action,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pump();

    expect(selectedAction, same(cancelAction));
  });
}
