import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/design_system/design_system.dart';
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
        foregroundColor: context.moto.textSecondary,
        elevation: 0,
      ),
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
                    address: profile.address,
                    isEditing: _isEditing,
                    onChanged: () => setState(() {}),
                  ),
                  if (_hasActiveTravel) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Não é possível editar o perfil enquanto houver uma viagem em andamento.',
                      style: TextStyle(fontSize: 12, color: context.moto.danger),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_isEditing)
                    MotoButton(
                      label: 'Editar',
                      large: false,
                      onPressed: !canEdit ? null : _onEditTapped,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: MotoButton(
                            label: 'Cancelar',
                            variant: MotoButtonVariant.glass,
                            large: false,
                            onPressed: isSaving ? null : _onCancelEdit,
                          ),
                        ),
                        const SizedBox(width: MotoSpace.s3),
                        Expanded(
                          child: MotoButton(
                            label: 'Salvar',
                            large: false,
                            loading: isSaving,
                            onPressed: isSaving || !(_formKey.currentState?.isValid ?? false) ? null : _onSave,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(MotoSpace.s4),
                    decoration: BoxDecoration(
                      color: context.moto.dangerSoft,
                      borderRadius: MotoRadius.brLg,
                      border: Border.all(color: context.moto.danger.withValues(alpha: .18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: context.moto.danger, size: 20),
                            const SizedBox(width: MotoSpace.s2),
                            Text(
                              'Zona de perigo',
                              style: TextStyle(
                                fontFamily: MotoFont.ui,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.moto.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MotoSpace.s2),
                        Text(
                          'Excluir a conta apaga seus dados e o histórico. Não dá pra desfazer.',
                          style: TextStyle(fontSize: 13, color: context.moto.textSecondary),
                        ),
                        const SizedBox(height: MotoSpace.s3),
                        Tooltip(
                          message: _hasActiveTravel ? 'Não é possível excluir a conta enquanto houver viagens em andamento.' : '',
                          child: MotoButton(
                            label: 'Excluir minha conta',
                            icon: Icons.delete_forever,
                            variant: MotoButtonVariant.danger,
                            large: false,
                            expand: false,
                            onPressed: _hasActiveTravel ? null : () => Modular.to.pushNamed('/delete-account/'),
                          ),
                        ),
                      ],
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
                  Icon(Icons.error_outline, size: 48, color: context.moto.danger),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      state.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MotoButton(
                    label: 'Tentar novamente',
                    large: false,
                    expand: false,
                    onPressed: () {
                      context.read<ProfileConfigurationBloc>().add(
                        ProfileLoadEvent(userId: widget.userId),
                      );
                    },
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
        backgroundColor: isError ? context.moto.danger : context.moto.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
