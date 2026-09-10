import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/modules/profile_configuration/domain/entities/profile_entity.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/blocs/profile_configuration_bloc.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/blocs/profile_configuration_event.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/blocs/profile_configuration_state.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/widgets/profile_form.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/widgets/profile_image_display.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/widgets/profile_image_picker.dart';

class ProfileConfigurationPage extends StatefulWidget {
  final String userId;

  const ProfileConfigurationPage({
    super.key,
    required this.userId,
  });

  @override
  State<ProfileConfigurationPage> createState() => _ProfileConfigurationPageState();
}

class _ProfileConfigurationPageState extends State<ProfileConfigurationPage> {
  final ProfileImagePicker _imagePicker = ProfileImagePicker();
  final GlobalKey<ProfileFormState> _formKey = GlobalKey<ProfileFormState>();
  bool _hasActiveTravel = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    context.read<ProfileConfigurationBloc>().add(
      ProfileLoadEvent(userId: widget.userId),
    );
    _checkActiveTravel();
  }

  Future<void> _checkActiveTravel() async {
    final travelRepo = Modular.get<TravelLocalRepository>();
    final active = await travelRepo.getActiveTravel();
    setState(() => _hasActiveTravel = active != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4E4E4E),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: BlocConsumer<ProfileConfigurationBloc, ProfileConfigurationState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            if (state.emailChanged) {
              _forceLogoutAfterEmailChange();
            } else {
              setState(() => _isEditing = false);
              _showSnackbar('Dados atualizados com sucesso!');
            }
          }
          if (state is ProfileUpdateFailure) {
            _showSnackbar(state.error.toString(), isError: true);
          }
          if (state is ProfileImageUploadSuccess) {
            _showSnackbar('Foto atualizada com sucesso!');
          }
          if (state is ProfileImageUploadFailure) {
            _showSnackbar(state.error.toString(), isError: true);
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProfileLoaded ||
              state is ProfileUpdateLoading ||
              state is ProfileImageUploadLoading ||
              state is ProfileUpdateSuccess ||
              state is ProfileImageUploadSuccess) {
            final profile = _resolveProfile(state);
            if (profile == null) return const Center(child: CircularProgressIndicator());

            final isSaving = state is ProfileUpdateLoading;
            final uploadState = state is ProfileImageUploadLoading ? state : null;
            final isUploading = uploadState != null;
            final canEdit = !_hasActiveTravel;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile image section
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ProfileImageDisplay(
                        photoUrl: profile.photoUrl,
                        name: profile.name,
                        radius: 50,
                      ),
                      if (isUploading)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                  if (isUploading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: uploadState.progress),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: isUploading || _hasActiveTravel ? null : _onPickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Alterar foto'),
                  ),
                  const SizedBox(height: 32),
                  // Form section
                  ProfileForm(
                    key: _formKey,
                    initialName: profile.name,
                    initialEmail: profile.email,
                    initialPhone: profile.phone ?? '',
                    isEditing: _isEditing,
                    onChanged: () => setState(() {}),
                  ),
                  if (_hasActiveTravel) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Não é possível editar o perfil enquanto houver uma viagem em andamento.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_isEditing)
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !canEdit ? null : _onEditTapped,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4685C0),
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Editar',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isSaving ? null : _onCancelEdit,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving || !(_formKey.currentState?.isValid ?? false) ? null : _onSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4685C0),
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      'Salvar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Danger Zone section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Zona de Perigo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ao excluir sua conta, todos os seus dados serão perdidos '
                    'e você não poderá mais acessar o aplicativo.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF4E4E4E)),
                  ),
                  const SizedBox(height: 12),
                  Tooltip(
                    message: _hasActiveTravel ? 'Não é possível excluir a conta enquanto houver viagens em andamento.' : '',
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _hasActiveTravel ? null : () => Modular.to.pushNamed('/delete-account/'),
                        icon: Icon(
                          Icons.delete_forever,
                          color: _hasActiveTravel ? Colors.grey.shade400 : Colors.red,
                        ),
                        label: Text(
                          'Excluir conta',
                          style: TextStyle(color: _hasActiveTravel ? Colors.grey.shade400 : Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _hasActiveTravel ? Colors.grey.shade300 : Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileUpdateFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      state.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ProfileConfigurationBloc>().add(
                        ProfileLoadEvent(userId: widget.userId),
                      );
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  ProfileEntity? _resolveProfile(ProfileConfigurationState state) {
    if (state is ProfileLoaded) return state.profile;
    if (state is ProfileUpdateLoading) return state.profile;
    if (state is ProfileUpdateSuccess) return state.profile;
    if (state is ProfileImageUploadLoading) return state.profile;
    if (state is ProfileImageUploadSuccess) return state.profile;
    return null;
  }

  Future<void> _onPickImage() async {
    final filePath = await _imagePicker.pickAndCropImage(context);
    if (filePath != null) {
      if (!mounted) return;
      context.read<ProfileConfigurationBloc>().add(
        ProfileImageUploadEvent(filePath: filePath),
      );
    }
  }

  void _onEditTapped() => setState(() => _isEditing = true);

  void _onCancelEdit() => setState(() => _isEditing = false);

  Future<void> _onSave() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    final password = await _askPasswordToConfirm(emailChanged: formState.emailChanged);
    if (password == null || password.isEmpty) return;
    if (!mounted) return;

    context.read<ProfileConfigurationBloc>().add(
      ProfileUpdateEvent(
        name: formState.name,
        email: formState.email,
        phone: formState.phone,
        password: password,
      ),
    );
  }

  Future<String?> _askPasswordToConfirm({required bool emailChanged}) {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirme sua senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emailChanged
                    ? 'Digite sua senha atual para confirmar a alteração. Como você está '
                        'mudando o e-mail, isso vai encerrar sua sessão e você precisará '
                        'fazer login novamente.'
                    : 'Digite sua senha atual para confirmar a alteração dos seus dados.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(passwordController.text),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _forceLogoutAfterEmailChange() async {
    _showSnackbar('E-mail atualizado! Faça login novamente.');
    await context.read<SignalRService>().disconnectAll();
    if (mounted) {
      await context.read<SignOutService>().signOut();
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
