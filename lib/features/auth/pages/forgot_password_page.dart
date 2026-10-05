import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_reset_otp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../../../core/widgets/ui_components.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _errorService = ErrorService();
  final _otpService = PasswordResetOtpService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtpCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _otpService.sendOtpCode(
        _emailController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(result['message'] ?? 'حدث خطأ أثناء إرسال رمز التحقق');
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi du code: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  void _showSuccessDialog() {
    final email = _emailController.text.trim();
    ModernDialog.showSuccess(
      context,
      title: 'تم إرسال رمز التحقق',
      message:
          'تم إرسال رمز التحقق إلى $email\n\n'
          'يرجى التحقق من صندوق الوارد الخاص بك وإدخال الرمز المكون من 6 أرقام.',
      barrierDismissible: false,
      onConfirm: () {
        Navigator.of(context).pop();
        Future.microtask(() {
          context.push('/verify-otp', extra: email);
        });
      },
    );
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(
      context,
      title: 'خطأ في إعادة تعيين كلمة المرور',
      message: error,
      barrierDismissible: false,
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!Validators.isValidEmail(value)) {
      return _errorService.getErrorMessage('AUTH_INVALID_EMAIL');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'استعادة كلمة المرور',
      heading: 'نسيت كلمة المرور؟',
      subtitle: 'أدخل بريدك الإلكتروني وسنرسل لك رمز تحقق لإعادة تعيينها',
      icon: Icons.lock_reset_rounded,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _sendOtpCode(),
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'أدخل بريدك الإلكتروني',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              AuthSubmitButton(
                text: 'إرسال رمز التحقق',
                icon: Icons.send_rounded,
                isLoading: _isLoading,
                onPressed: _sendOtpCode,
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
