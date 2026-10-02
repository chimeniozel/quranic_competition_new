import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_reset_otp_service.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void dispose() {
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

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        setState(() => _isVerified = true);
        _showSuccessDialog();
      } else {
        _showErrorDialog(result['message'] ?? 'رمز التحقق غير صحيح');
      }
    } catch (e) {
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

      setState(() => _isLoading = false);

      if (result['success'] == true) {
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
      setState(() => _isLoading = false);
      _showErrorDialog(_errorService.analyzeException(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من الرمز'),
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
                      'التحقق من الرمز',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أدخل رمز التحقق المكون من 6 أرقام الذي تم إرساله إلى\n${widget.email}',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                validator: _validateOtp,
                decoration: InputDecoration(
                  labelText: 'رمز التحقق',
                  hintText: '000000',
                  prefixIcon: const FaIcon(FontAwesomeIcons.lock, size: 20),
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
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _isVerified ? null : _verifyOtp,
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
                      'التحقق من الرمز',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'لم تستلم الرمز؟',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _resendOtp,
                    child: const Text('إعادة إرسال'),
                  ),
                ],
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
