import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Duration delay;

  const SplashScreen({super.key, this.delay = const Duration(seconds: 2)});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(
      widget.delay,
      () => Modular.to.navigate('/bootstrap'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Image.asset(
          'assets/images/moto_driver_logo.png',
          width: 257,
          height: 103,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 257, height: 103, child: Placeholder()),
        ),
      ),
    );
  }
}
