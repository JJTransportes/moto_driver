import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<ProfileConfigurationBloc>().add(
      ProfileLoadEvent(userId: widget.userId),
    );
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
            _showSnackbar('Dados atualizados com sucesso!');
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
                    onPressed: isUploading ? null : _onPickImage,
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
                    isLoading: isSaving,
                    onSave: _onSave,
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

  void _onSave() {
    final formState = _formKey.currentState;
    if (formState == null) return;

    context.read<ProfileConfigurationBloc>().add(
      ProfileUpdateEvent(
        name: formState.name,
        email: formState.email,
        phone: formState.phone,
      ),
    );
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
