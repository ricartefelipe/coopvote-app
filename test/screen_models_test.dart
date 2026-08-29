import 'package:coopvote_app/screen_flow/screen_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppScreen.fromJson', () {
    test('interpreta todos os componentes de FORMULARIO', () {
      final screen = AppScreen.fromJson({
        'tipo': 'FORMULARIO',
        'titulo': 'Cadastro',
        'itens': [
          {'tipo': 'TEXTO', 'texto': 'Preencha os dados.'},
          {
            'tipo': 'INPUT_TEXTO',
            'id': 'nome',
            'titulo': 'Nome',
            'valor': 'Maria',
          },
          {
            'tipo': 'INPUT_NUMERO',
            'id': 'quantidade',
            'titulo': 'Quantidade',
            'valor': 2,
          },
          {
            'tipo': 'INPUT_DATA',
            'id': 'data',
            'titulo': 'Data',
            'valor': '28/08/2026',
          },
        ],
        'botaoOk': {
          'texto': 'Salvar',
          'url': 'https://api.example.test/salvar',
          'body': {'origem': 'mobile', 'nome': 'valor anterior'},
        },
        'botaoCancelar': {
          'texto': 'Cancelar',
          'url': 'https://api.example.test/cancelar',
        },
      });

      expect(screen, isA<FormScreen>());
      final form = screen as FormScreen;
      expect(form.items, hasLength(4));
      expect(form.items[0], isA<TextFormItem>());
      expect(form.items[1], isA<TextInputFormItem>());
      expect(form.items[2], isA<NumberInputFormItem>());
      expect(form.items[3], isA<DateInputFormItem>());
      expect(form.cancelButton?.text, 'Cancelar');
      expect(form.okButton.payloadWith({'nome': 'João'}), {
        'origem': 'mobile',
        'nome': 'João',
      });
    });

    test('interpreta SELECAO com corpo opcional', () {
      final screen = AppScreen.fromJson({
        'tipo': 'SELECAO',
        'titulo': 'Opções',
        'itens': [
          {
            'texto': 'Primeira opção',
            'url': 'https://api.example.test/opcao',
            'body': {'id': 1},
          },
          {'texto': 'Segunda opção', 'url': 'https://api.example.test/outra'},
        ],
      });

      expect(screen, isA<SelectionScreen>());
      final selection = screen as SelectionScreen;
      expect(selection.items, hasLength(2));
      expect(selection.items.first.body, {'id': 1});
      expect(selection.items.last.body, isNull);
      expect(selection.items.last.payloadWith({}), isNull);
    });

    test('rejeita tipo de item desconhecido', () {
      expect(
        () => AppScreen.fromJson({
          'tipo': 'FORMULARIO',
          'titulo': 'Cadastro',
          'itens': [
            {'tipo': 'INPUT_EMAIL'},
          ],
          'botaoOk': {
            'texto': 'Salvar',
            'url': 'https://api.example.test/salvar',
          },
        }),
        throwsA(isA<ScreenProtocolException>()),
      );
    });

    test('rejeita identificadores duplicados', () {
      expect(
        () => AppScreen.fromJson({
          'tipo': 'FORMULARIO',
          'titulo': 'Cadastro',
          'itens': [
            {'tipo': 'INPUT_TEXTO', 'id': 'nome', 'titulo': 'Nome'},
            {'tipo': 'INPUT_TEXTO', 'id': 'nome', 'titulo': 'Apelido'},
          ],
          'botaoOk': {
            'texto': 'Salvar',
            'url': 'https://api.example.test/salvar',
          },
        }),
        throwsA(isA<ScreenProtocolException>()),
      );
    });

    test('rejeita tipo de tela desconhecido', () {
      expect(
        () => AppScreen.fromJson({'tipo': 'DETALHE', 'titulo': 'Detalhe'}),
        throwsA(isA<ScreenProtocolException>()),
      );
    });

    test('rejeita callback que não é uma URL absoluta', () {
      expect(
        () => AppScreen.fromJson({
          'tipo': 'SELECAO',
          'titulo': 'Opções',
          'itens': [
            {'texto': 'Abrir', 'url': '/caminho/relativo'},
          ],
        }),
        throwsA(isA<ScreenProtocolException>()),
      );
    });
  });
}
