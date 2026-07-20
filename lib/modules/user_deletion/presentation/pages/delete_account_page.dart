import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_bloc.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_event.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_state.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  int _step = 0; // 0 = warning, 1 = password
  final _passwordController = TextEditingController();
  bool _isPasswordValid = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final isValid = _passwordController.text.isNotEmpty;
    if (isValid != _isPasswordValid) {
      setState(() => _isPasswordValid = isValid);
    }
  }

  void _advanceToPasswordStep() {
    setState(() => _step = 1);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step = 0);
    }
  }

  void _onConfirmDelete() {
    context.read<DeleteAccountBloc>().add(
          DeleteAccountRequested(password: _passwordController.text),
        );
  }

  Future<void> _handleSuccess() async {
    await context.read<SignalRService>().disconnectAll();
    if (mounted) {
      await context.read<SignOutService>().signOut();
    }
  }

  void _showError(Exception error) {
    final message = _resolveErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolveErrorMessage(Exception error) {
    if (error is UnauthorizedException) return error.toString();
    if (error is ValidationException) return error.toString();
    if (error is NetworkException) return error.toString();
    if (error is ServerException) return error.toString();
    return 'Erro inesperado. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => context.read<DeleteAccountBloc>(),
      child: PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _step == 1) {
            _goBack();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_step == 0 ? 'Excluir conta' : 'Confirme sua senha'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4E4E4E),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            ),
          ),
          backgroundColor: Colors.white,
          body: BlocListener<DeleteAccountBloc, DeleteAccountState>(
            listener: (context, state) {
              if (state is DeleteAccountSuccess) {
                _handleSuccess();
              }
              if (state is DeleteAccountFailure) {
                _showError(state.error);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _step == 0 ? _buildWarningStep() : _buildPasswordStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tem certeza que deseja excluir sua conta?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Esta ação é irreversível e todos os seus dados, incluindo '
          'histórico de viagens, serão perdidos.',
          style: TextStyle(fontSize: 16, color: Color(0xFF4E4E4E)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _advanceToPasswordStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return BlocBuilder<DeleteAccountBloc, DeleteAccountState>(
      builder: (context, state) {
        final isLoading = state is DeleteAccountLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação é irreversível. Digite sua senha atual '
              'para confirmar a exclusão da sua conta.',
              style: TextStyle(fontSize: 16, color: Color(0xFF4E4E4E)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (!_isPasswordValid || isLoading)
                    ? null
                    : _onConfirmDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirmar exclusão',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isLoading ? null : _goBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
