import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/design_system/design_system.dart';

void main() {
  test('máscaras e validadores', () {
    TextEditingValue f(TextInputFormatter m, String s) =>
        m.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s));
    expect(f(MotoMasks.cpf, '12345678909').text, '123.456.789-09');
    expect(f(MotoMasks.tel, '12991234567').text, '(12) 99123-4567');
    expect(f(MotoMasks.data, '12031990').text, '12/03/1990');
    expect(MotoValidators.cpf('123.456.789-09'), isNull);
    expect(MotoValidators.cpf('111.111.111-11'), isNotNull);
    expect(MotoValidators.cpf('123.456'), 'Faltam 5 dígitos.');
    expect(MotoValidators.data('31/02/2000'), isNotNull);
    expect(
      MotoValidators.maior16(MotoDateField.format(DateTime.now())),
      isNotNull,
    );
    expect(MotoValidators.email('ana@jacarei.sp.gov.br'), isNull);
    expect(MotoPasswordRule.level('Jacarei2026'), 3);
    expect(MotoValidators.senha('Jacarei@2026'), isNull);
    expect(MotoValidators.match(() => 'a@b.com')('a@b.co'), isNotNull);
  });

  testWidgets('seletor com busca, senha e etapas', (t) async {
    String? orgao;
    final senha = TextEditingController();
    await t.pumpWidget(
      MaterialApp(
        theme: MotoTheme.claro(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const MotoStepper(
                  steps: ['Seus dados', 'Acesso', 'Revisão'],
                  current: 1,
                ),
                MotoSelectField<String>(
                  label: 'Órgão',
                  options: const [
                    MotoOption('sms', 'Secretaria de Saúde'),
                    MotoOption('sme', 'Secretaria de Educação'),
                  ],
                  onChanged: (v) => orgao = v,
                ),
                TextField(controller: senha),
                MotoStrengthMeter(controller: senha),
                MotoPasswordRules(controller: senha),
                MotoDateField(
                  label: 'Nascimento',
                  controller: TextEditingController(),
                  birthDate: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(MotoSelectField<String>));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'saude');
    await t.pumpAndSettle();
    expect(find.text('Secretaria de Educação'), findsNothing);
    await t.tap(find.text('Secretaria de Saúde'));
    await t.pumpAndSettle();
    expect(orgao, 'sms');
    await t.enterText(find.byType(TextField).at(0), 'Jacarei@2026');
    await t.pumpAndSettle();
    expect(find.text('Forte'), findsOneWidget);
  });
}
