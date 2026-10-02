import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_reset_otp_service.dart';
import '../../../core/theme/app_theme.dart';
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

      setState(() {
        _isLoading = false;
      });

      print('📧 OTP Service result: $result');

      if (result['success'] == true) {
        print('✅ Showing success dialog');
        _showSuccessDialog();
      } else {
        print('❌ Showing error dialog: ${result['message']}');
        _showErrorDialog(result['message'] ?? 'حدث خطأ أثناء إرسال رمز التحقق');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Exception in _sendOtpCode: $e');
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  void _showSuccessDialog() {
    print('✅ _showSuccessDialog called');
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
    print('❌ _showErrorDialog called with error: $error');
    ModernDialog.showError(
      context,
      title: 'خطأ في إعادة تعيين كلمة المرور',
      message: error,
      barrierDismissible: false,
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidEmail(value)) {
      return _errorService.getErrorMessage('AUTH_INVALID_EMAIL');
    }
    return null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استعادة كلمة المرور'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header avec logo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logos/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'استعادة كلمة المرور',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أدخل بريدك الإلكتروني وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                validator: _validateEmail,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'أدخل بريدك الإلكتروني',
                  prefixIcon: const FaIcon(FontAwesomeIcons.envelope, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide: const BorderSide(color: AppTheme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide: const BorderSide(color: AppTheme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide: const BorderSide(color: AppTheme.errorColor),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide: const BorderSide(
                      color: AppTheme.errorColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingS,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _sendOtpCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                        vertical: AppTheme.spacingS,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                    ),
                    child: const Text(
                      'إرسال رمز التحقق',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('العودة لتسجيل الدخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
