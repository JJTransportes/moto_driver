// Spec push-notification-sounds (req 1.1, 1.3, 1.5, 3.1): o som das notificações está nos dois
// pacotes do app (Android e iOS), é o mesmo arquivo, em formato aceito e referenciado no iOS.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _name = 'moto_notification.wav';
const _android = 'android/app/src/main/res/raw/$_name';
const _ios = 'ios/Runner/$_name';
const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

void main() {
  late Uint8List androidBytes;
  late Uint8List iosBytes;

  setUpAll(() {
    androidBytes = File(_android).readAsBytesSync();
    iosBytes = File(_ios).readAsBytesSync();
  });

  test('o som existe no Android (res/raw) e no iOS (pacote)', () {
    expect(File(_android).existsSync(), isTrue);
    expect(File(_ios).existsSync(), isTrue);
  });

  test('é exatamente o mesmo arquivo nas duas plataformas', () {
    expect(iosBytes.length, androidBytes.length);
    expect(iosBytes, androidBytes);
  });

  test('o nome é minúsculo, com _ e extensão .wav (exigência do Android e do OneSignal)', () {
    expect(_name, matches(RegExp(r'^[a-z0-9_]+\.wav$')));
  });

  group('formato do arquivo', () {
    late ByteData header;

    setUp(() => header = ByteData.sublistView(androidBytes));

    test('é um WAV PCM (aceito pelo Android e pelo iOS)', () {
      expect(String.fromCharCodes(androidBytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(androidBytes.sublist(8, 12)), 'WAVE');
      expect(header.getUint16(20, Endian.little), 1); // 1 = PCM linear
    });

    test('o tamanho declarado bate com o arquivo', () {
      expect(header.getUint32(4, Endian.little) + 8, androidBytes.length);
    });

    test('tem duração entre 3 e 6 segundos (som repetido 2 vezes) e bem abaixo de 30 s', () {
      final channels = header.getUint16(22, Endian.little);
      final rate = header.getUint32(24, Endian.little);
      final bits = header.getUint16(34, Endian.little);
      final dataSize = header.getUint32(40, Endian.little);
      final seconds = dataSize / (rate * channels * bits / 8);

      expect(seconds, inInclusiveRange(3.0, 6.0));
      expect(seconds, lessThan(30));
    });
  });

  test('o iOS referencia o som no projeto e o inclui nos recursos do app', () {
    final project = File(_pbxproj).readAsStringSync();

    expect(project, contains('/* $_name */ = {isa = PBXFileReference'));
    expect(project, contains('$_name in Resources'));
  });

  test('o app não carrega outro áudio de terceiros além do som registrado', () {
    final audio = <String>[];
    for (final root in ['android/app/src/main/res', 'ios/Runner', 'assets']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && RegExp(r'\.(wav|mp3|ogg|aiff|caf|m4a)$').hasMatch(entity.path)) {
          audio.add(entity.path.replaceAll('\\', '/').split('/').last);
        }
      }
    }

    expect(audio.toSet(), {_name});
  });
}
