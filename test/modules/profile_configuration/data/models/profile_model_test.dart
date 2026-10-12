import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/modules/profile_configuration/data/models/profile_model.dart';

void main() {
  Map<String, dynamic> baseJson({Object? address}) => {
        'id': 'driver-1',
        'name': 'João Motorista',
        'email': 'joao@example.com',
        'phone': '11999999999',
        'photoUrl': null,
        // Campos legados de nível raiz — devem ser ignorados por fromJson,
        // já que address.city/address.state são a fonte real (ver F05).
        'city': 'CidadeLegado',
        'state': 'XX',
        if (address != null) 'address': address,
      };

  group('ProfileModel.fromJson — address (F05)', () {
    test('lê o endereço a partir do objeto aninhado address.*', () {
      final model = ProfileModel.fromJson(baseJson(address: {
        'lineOne': 'Rua Exemplo, 123',
        'lineTwo': 'Apto 45',
        'district': 'Centro',
        'city': 'São Paulo',
        'state': 'SP',
        'postalCode': '01000-000',
        'countryCode': 'BR',
      }));

      expect(model.address, isNotNull);
      expect(model.address!.lineOne, 'Rua Exemplo, 123');
      expect(model.address!.lineTwo, 'Apto 45');
      expect(model.address!.district, 'Centro');
      expect(model.address!.city, 'São Paulo');
      expect(model.address!.state, 'SP');
      expect(model.address!.postalCode, '01000-000');
      expect(model.address!.countryCode, 'BR');
    });

    test('NÃO usa os campos legados city/state de nível raiz quando address existe', () {
      final model = ProfileModel.fromJson(baseJson(address: {
        'lineOne': 'Rua Exemplo, 123',
        'city': 'São Paulo',
        'state': 'SP',
        'countryCode': 'BR',
      }));

      expect(model.address!.city, 'São Paulo');
      expect(model.address!.city, isNot('CidadeLegado'));
      expect(model.address!.state, isNot('XX'));
    });

    test('address ausente no JSON resulta em address nulo', () {
      final model = ProfileModel.fromJson(baseJson());

      expect(model.address, isNull);
    });

    test('address explicitamente nulo no JSON resulta em address nulo', () {
      final model = ProfileModel.fromJson(baseJson(address: null));

      expect(model.address, isNull);
    });

    test('toEntity() propaga o endereço para a ProfileEntity', () {
      final model = ProfileModel.fromJson(baseJson(address: {
        'lineOne': 'Rua Exemplo, 123',
        'city': 'São Paulo',
        'state': 'SP',
        'countryCode': 'BR',
      }));

      final entity = model.toEntity();

      expect(entity.address, isNotNull);
      expect(entity.address!.city, 'São Paulo');
    });
  });
}
