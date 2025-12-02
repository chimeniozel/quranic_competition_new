import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_validation_service.dart';
import '../../../core/widgets/password_field_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_components.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? email;

  const ResetPasswordPage({super.key, this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _errorService = ErrorService();
  final _passwordService = PasswordValidationService();
  final _supabase = Supabase.instance.client;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.email == null || widget.email!.isEmpty) {
      _showErrorDialog('البريد الإلكتروني غير متوفر. يرجى المحاولة مرة أخرى.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Vérifier la validation du mot de passe
      final validationResult = _passwordService.validatePassword(
        _newPasswordController.text,
      );

      if (!validationResult.isValid) {
        throw Exception(validationResult.errors.first);
      }

      // ملاحظة: البريد الإلكتروني موجود في auth.users وليس في profiles
      // لا يمكن البحث في profiles بالبريد الإلكتروني
      // Edge Function ستتحقق من وجود المستخدم في auth.users

      print('🔐 Starting password reset for email: ${widget.email}');

      // استخدام Edge Function لإعادة تعيين كلمة المرور
      try {
        print('🔐 Calling reset-password Edge Function...');
        final response = await _supabase.functions.invoke(
          'reset-password',
          body: {
            'user_email': widget.email!,
            'new_password': _newPasswordController.text,
          },
        );

        print('🔐 Edge Function response status: ${response.status}');
        print('🔐 Edge Function response data: ${response.data}');

        // التحقق من response.data أيضاً
        final responseData = response.data as Map<String, dynamic>?;
        final isSuccess =
            response.status == 200 &&
            (responseData?['success'] == true ||
                responseData?['success'] == null);

        if (!isSuccess) {
          final errorData = responseData ?? response.data;
          final errorMessage =
              errorData?['error'] ??
              errorData?['message'] ??
              'فشل إعادة تعيين كلمة المرور';
          print('❌ Edge Function error: $errorMessage');
          throw Exception(errorMessage);
        }

        print('✅ Password reset successful');
      } catch (e, stackTrace) {
        print('❌ Error in reset password: $e');
        print('❌ Stack trace: $stackTrace');

        // إذا فشلت Edge Function، نعرض رسالة خطأ واضحة
        throw Exception(
          'لا يمكن تغيير كلمة المرور حالياً. يرجى المحاولة مرة أخرى.\n\n'
          'التفاصيل: ${e.toString()}',
        );
      }

      if (mounted) {
        print('✅ Calling _showSuccessDialog');
        try {
          _showSuccessDialog();
          print('✅ Success dialog shown successfully');
        } catch (dialogError, dialogStack) {
          print('❌ Error showing success dialog: $dialogError');
          print('❌ Dialog stack trace: $dialogStack');
          // لا نرمي exception هنا، لأن العملية نجحت بالفعل
          // فقط نعرض error dialog كبديل
          _showErrorDialog(
            'تم إعادة تعيين كلمة المرور بنجاح، لكن حدث خطأ في عرض الرسالة.',
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _resetPassword: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        print('❌ Calling _showErrorDialog');
        _showErrorDialog(_errorService.analyzeException(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    print('✅ _showSuccessDialog called');
    print('✅ Context mounted: $mounted');

    if (!mounted) {
      print('❌ Context not mounted, cannot show dialog');
      return;
    }

    try {
      ModernDialog.showSuccess(
        context,
        title: 'تم إعادة تعيين كلمة المرور',
        message: 'تم إعادة تعيين كلمة المرور بنجاح!\n\n'
            'يرجى تسجيل الدخول بكلمة المرور الجديدة.',
        barrierDismissible: false,
        onConfirm: () {
          Navigator.of(context).pop();
          context.go('/login');
        },
      );
      print('✅ Success dialog shown');
    } catch (e, stackTrace) {
      print('❌ Error in _showSuccessDialog: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعادة تعيين كلمة المرور'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Form(
          key: _formKey,
          child: Column(
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
                      'إعادة تعيين كلمة المرور',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أدخل كلمة المرور الجديدة',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Nouveau mot de passe avec validation avancée
              PasswordFieldWidget(
                controller: _newPasswordController,
                labelText: 'كلمة المرور الجديدة',
                showStrengthIndicator: true,
                showSuggestions: true,
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Confirmation du nouveau mot de passe
              ConfirmPasswordFieldWidget(
                controller: _confirmPasswordController,
                passwordController: _newPasswordController,
                labelText: 'تأكيد كلمة المرور الجديدة',
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Bouton de réinitialisation
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _resetPassword,
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
                      'إعادة تعيين كلمة المرور',
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
