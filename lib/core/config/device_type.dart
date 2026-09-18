import 'dart:io';

/// Tipo de dispositivo enviado nas chamadas de autenticação
/// (device binding em refresh tokens — backend: `android` | `ios`).
///
/// O app é mobile-only (Android/iOS); o admin web não envia `device`
/// (token fica neutro, sem vínculo).
String get deviceType => Platform.isIOS ? 'ios' : 'android';
