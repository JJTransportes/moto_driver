import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moto_driver/core/theme/app_theme.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_bloc.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_event.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_state.dart';
import 'package:moto_driver/widgets/app_button.dart';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  @override
  void initState() {
    super.initState();
    context.read<UsageTermsBloc>().add(const CheckStatus());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UsageTermsBloc, UsageTermsState>(
      listener: (context, state) {
        if (state is UsageTermsAccepted) {
          Modular.to.navigate('/home');
        }
      },
      builder: (context, state) {
        return switch (state) {
          UsageTermsInitial() ||
          UsageTermsChecking() ||
          UsageTermsLoading() =>
            _buildLoading(),
          UsageTermsLoaded(:final terms) ||
          UsageTermsSubmitting(:final terms) =>
            _buildTerms(
              terms: terms,
              isSubmitting: state is UsageTermsSubmitting,
            ),
          UsageTermsError(:final message, :final isRetryable) =>
            _buildError(message: message, isRetryable: isRetryable),
          UsageTermsAccepted() => const SizedBox.shrink(),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildTerms({
    required dynamic terms,
    required bool isSubmitting,
  }) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Termos de Uso',
          style: GoogleFonts.robotoFlex(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: PopScope(
        canPop: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terms.title as String,
                      style: GoogleFonts.robotoFlex(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...(terms.subTerms as List).map(
                      (subTerm) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subTerm.title as String,
                              style: GoogleFonts.robotoFlex(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subTerm.content as String,
                              style: GoogleFonts.robotoFlex(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    AppButton(
                      label: 'Aceitar',
                      loading: isSubmitting,
                      onPressed: () {
                        context.read<UsageTermsBloc>().add(const AcceptTerms());
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Leia os termos antes de decidir.',
                                  ),
                                ),
                              );
                              context
                                  .read<UsageTermsBloc>()
                                  .add(const DeclineTerms());
                            },
                      child: Text(
                        'Recusar',
                        style: GoogleFonts.robotoFlex(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError({
    required String message,
    required bool isRetryable,
  }) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: PopScope(
        canPop: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: GoogleFonts.robotoFlex(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isRetryable) ...[
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Tentar novamente',
                    onPressed: () {
                      context.read<UsageTermsBloc>().add(const LoadTerms());
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
