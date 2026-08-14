import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/dev_auth_config.dart';
import '../services/entitlement_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/botanical_background.dart';
import '../widgets/logo_mark.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  static const routeName = '/sign-in';

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    await _completeSignIn(_authService.signInWithGoogle);
  }

  Future<void> _signInWithApple() async {
    await _completeSignIn(_authService.signInWithApple);
  }

  Future<void> _signInForEmulator() async {
    await _completeSignIn(_authService.signInWithEmulatorTestUser);
  }

  Future<void> _completeSignIn(Future<void> Function() signIn) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await signIn();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(MainShell.routeName);
      unawaited(_refreshSignedInServices());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshSignedInServices() async {
    try {
      await EntitlementService().getCurrentPlan();
    } catch (error) {
      debugPrint('Entitlement refresh after sign-in skipped: $error');
    }
    try {
      await NotificationService.instance.registerDeviceToken();
    } catch (error) {
      debugPrint('Push token refresh after sign-in skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotanicalBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LogoMark(size: 64),
                const Spacer(),
                const _FreeUseBanner(),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: .14),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.green,
                      size: 58,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Center(
                  child: Text(
                    context.tr(
                      'Bakım geçmişin hesabında güvende kalsın.',
                      'Keep your care history safe in your account.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title.copyWith(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    context.tr(
                      'Premium hakların, teşhislerin ve bitki listen güvenli hesabınla eşleşir.',
                      'Your Premium access, diagnoses and plant list stay linked to your secure account.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.muted),
                  ),
                ),
                const Spacer(),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: .28),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.muted.copyWith(
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _isLoading ? null : _signInWithApple,
                      icon: const Icon(Icons.apple),
                      label: Text(
                        _isLoading
                            ? context.tr('Bağlanıyor...', 'Connecting...')
                            : context.tr(
                                'Apple ile devam et',
                                'Continue with Apple',
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                AppButton(
                  label: _isLoading
                      ? context.tr('Bağlanıyor...', 'Connecting...')
                      : context.tr(
                          'Google ile devam et',
                          'Continue with Google',
                        ),
                  icon: Icons.login_rounded,
                  onPressed: _isLoading ? null : _signInWithGoogle,
                ),
                if (DevAuthConfig.allowEmulatorLogin) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInForEmulator,
                    icon: const Icon(Icons.developer_mode),
                    label: Text(
                      context.tr('Emülatörde test et', 'Test in emulator'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    context.tr(
                      'Satın alma gerekmeden hesabınla devam edebilirsin.',
                      'You can continue with your account without purchasing.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.muted.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeUseBanner extends StatelessWidget {
  const _FreeUseBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 374),
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF4FBF2), Color(0xFFFFF6E9)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .9)),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: .16),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  context.tr('ÜCRETSİZ KULLANILABİLİR', 'FREE TO USE'),
                  maxLines: 1,
                  style: AppTextStyles.muted.copyWith(
                    color: AppColors.darkGreen,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .25,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.warning.withValues(alpha: .86),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}
