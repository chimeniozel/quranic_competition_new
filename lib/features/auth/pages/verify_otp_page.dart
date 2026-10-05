import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_reset_otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_layout.dart';
import '../../../core/widgets/ui_components.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;

  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _errorService = ErrorService();
  final _otpService = PasswordResetOtpService();

  bool _isLoading = false;
  bool _isVerified = false;
  // Délai avant de pouvoir redemander un code (évite les envois en boucle)
  static const _resendDelay = 60;
  int _resendCountdown = _resendDelay;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown(rebuild: false);
  }

  void _startResendCountdown({bool rebuild = true}) {
    _resendTimer?.cancel();
    if (rebuild) {
      setState(() => _resendCountdown = _resendDelay);
    } else {
      _resendCountdown = _resendDelay;
    }
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _otpService.verifyOtpCode(
        widget.email,
        _otpController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        setState(() => _isVerified = true);
        _showSuccessDialog();
      } else {
        _showErrorDialog(result['message'] ?? 'رمز التحقق غير صحيح');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  void _showSuccessDialog() {
    ModernDialog.showSuccess(
      context,
      title: 'تم التحقق من الرمز',
      message:
          'تم التحقق من رمز التحقق بنجاح!\n\n'
          'يمكنك الآن إعادة تعيين كلمة المرور.',
      barrierDismissible: false,
      confirmText: 'متابعة',
      onConfirm: () {
        Navigator.of(context).pop();
        context.push('/reset-password', extra: widget.email);
      },
    );
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(
      context,
      title: 'خطأ في التحقق',
      message: error,
      barrierDismissible: false,
    );
  }

  String? _validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال رمز التحقق';
    }
    if (value.length != 6) {
      return 'رمز التحقق يجب أن يكون 6 أرقام';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'رمز التحقق يجب أن يحتوي على أرقام فقط';
    }
    return null;
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);

    try {
      final result = await _otpService.sendOtpCode(widget.email);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _startResendCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إرسال رمز جديد إلى بريدك الإلكتروني'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        _showErrorDialog(result['message'] ?? 'فشل إرسال رمز جديد');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'التحقق من الرمز',
      heading: 'أدخل رمز التحقق',
      subtitle: 'أرسلنا رمزاً من 6 أرقام إلى\n${widget.email}',
      icon: Icons.mark_email_read_rounded,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                // Chiffres uniquement (lettres et espaces collés refusés)
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.length == 6 && !_isLoading && !_isVerified) {
                    _verifyOtp();
                  }
                },
                style: AppTheme.headingLarge.copyWith(
                  fontSize: 30,
                  letterSpacing: 10,
                ),
                validator: _validateOtp,
                decoration: const InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              AuthSubmitButton(
                text: 'التحقق من الرمز',
                icon: Icons.verified_rounded,
                isLoading: _isLoading,
                onPressed: _isVerified ? null : _verifyOtp,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('لم تستلم الرمز؟', style: AppTheme.bodyMedium),
                  TextButton(
                    onPressed:
                        _isLoading || _resendCountdown > 0 ? null : _resendOtp,
                    child: Text(
                      _resendCountdown > 0
                          ? 'إعادة الإرسال بعد $_resendCountdown ث'
                          : 'إعادة إرسال',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      footer: [
        TextButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('العودة لتسجيل الدخول'),
        ),
      ],
    );
  }
}
