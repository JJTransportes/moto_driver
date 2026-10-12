import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/widgets/profile_form.dart';

void main() {
  Widget buildForm({ProfileAddressEntity? address, bool isEditing = false}) {
    return MaterialApp(
      home: Scaffold(
        body: ProfileForm(
          initialName: 'João Motorista',
          initialEmail: 'joao@example.com',
          initialPhone: '11999999999',
          isEditing: isEditing,
          address: address,
        ),
      ),
    );
  }

  group('ProfileForm — exibição de endereço (F05)', () {
    testWidgets('renderiza o campo Endereço somente leitura quando address não é nulo', (tester) async {
      const address = ProfileAddressEntity(
        lineOne: 'Rua Exemplo, 123',
        district: 'Centro',
        city: 'São Paulo',
        state: 'SP',
        countryCode: 'BR',
      );

      await tester.pumpWidget(buildForm(address: address));

      expect(find.text('Endereço'), findsOneWidget);
      expect(find.text(address.formatted), findsOneWidget);

      final field = tester.widget<TextField>(
        find.ancestor(
          of: find.text(address.formatted),
          matching: find.byType(TextField),
        ),
      );
      expect(field.enabled, isFalse);
      expect(field.readOnly, isTrue);
    });

    testWidgets('não renderiza nenhum campo de endereço quando address é nulo', (tester) async {
      await tester.pumpWidget(buildForm(address: null));

      expect(find.text('Endereço'), findsNothing);
    });
  });
}
