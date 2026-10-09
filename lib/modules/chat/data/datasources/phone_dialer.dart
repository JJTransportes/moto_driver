import 'package:url_launcher/url_launcher.dart';

/// Abre o discador do aparelho. Isolado atrás de uma interface para a ligação
/// ser testável sem plataforma.
abstract class IPhoneDialer {
  /// Abre o discador com [phone] preenchido, SEM iniciar a chamada. Devolve
  /// `false` se o aparelho não consegue abrir o discador.
  Future<bool> dial(String phone);
}

class PhoneDialer implements IPhoneDialer {
  @override
  Future<bool> dial(String phone) async {
    final digits = sanitizePhone(phone);
    if (digits == null) return false;

    try {
      // `tel:` só abre o discador; quem aperta "ligar" é o motorista.
      return await launchUrl(Uri(scheme: 'tel', path: digits));
    } catch (_) {
      return false;
    }
  }
}

/// Mantém dígitos e o `+` inicial (formatos como `(12) 99988-7766` viram um
/// número discável). Devolve `null` se não sobrar nenhum dígito.
String? sanitizePhone(String raw) {
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return hasPlus ? '+$digits' : digits;
}
