import 'package:flutter/material.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';
import 'package:moto_driver/modules/driver_availability/domain/entities/driver_availability_entity.dart';

/// Bottom sheet de ativação do modo de atendimento (RF02/RF03/RF04).
class AvailabilitySheet {
  static bool _isOpen = false;

  /// Guard anti-duplicação: instâncias empilhadas de HomeScreen
  /// (navegações repetidas para /home) reexecutam o initState.
  static bool get isOpen => _isOpen;

  /// Mostra o sheet de ativação.
  ///
  /// Retorna [DriverAvailabilityEntity] se o motorista confirmou
  /// (POST bem-sucedido), ou null se cancelou/dispensou.
  static Future<DriverAvailabilityEntity?> show(
    BuildContext context, {
    required AvailabilityDatasource datasource,
  }) async {
    if (_isOpen) return null;
    _isOpen = true;
    try {
      return await showModalBottomSheet<DriverAvailabilityEntity>(
        context: context,
        isDismissible: true, // dispensar = Cancelar
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => AvailabilitySheetBody(datasource: datasource),
      );
    } finally {
      _isOpen = false;
    }
  }
}

class AvailabilitySheetBody extends StatefulWidget {
  final AvailabilityDatasource datasource;

  const AvailabilitySheetBody({super.key, required this.datasource});

  @override
  State<AvailabilitySheetBody> createState() => _AvailabilitySheetBodyState();
}

class _AvailabilitySheetBodyState extends State<AvailabilitySheetBody> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final entity = await widget.datasource.activate();
      if (!mounted) return;
      Navigator.of(context).pop(entity);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _friendlyMessage(e);
      });
    }
  }

  String _friendlyMessage(Object e) {
    if (e is NetworkException) {
      return 'Sem conexão. Tente novamente.';
    }
    if (e is UnauthorizedException) {
      return 'Sessão expirada. Faça login novamente.';
    }
    return 'Não foi possível ativar. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Atendimento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.moto.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ao clicar no botão abaixo você entrará em modo de atendimento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.moto.textPrimary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.moto.danger),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.moto.textPrimary,
                      side: BorderSide(color: context.moto.borderDefault),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.moto.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.moto.textOnAccent,
                            ),
                          )
                        : const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
