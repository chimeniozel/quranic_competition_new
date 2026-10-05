import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/widgets/password_field_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_ui.dart';
import '../widgets/auth_layout.dart';
import '../../../core/widgets/ui_components.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _errorService = ErrorService();

  final _countryCodeController = TextEditingController(text: '222');
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();

  String _role = 'membre'; // Valeurs possibles: membre, jury, admin
  bool _isLoading = false;

  void _submit() async {
    // Un envoi est déjà en cours : on ignore les appuis répétés
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _authService.signUp(
      countryCode: _countryCodeController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _role,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorDialog(error);
    } else {
      _showSuccessDialog();
    }
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(context, title: 'خطأ في التسجيل', message: error);
  }

  void _showSuccessDialog() {
    ModernDialog.showSuccess(
      context,
      title: 'تم التسجيل بنجاح',
      message:
          'تم إنشاء حسابك بنجاح!\n\n'
          'في انتظار توثيق حسابك من قبل الإدارة.\n'
          'بعد ذلك، ستتمكن من تسجيل الدخول.',
      onConfirm: () {
        Navigator.of(context).pop();
        context.go('/login');
      },
    );
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (value.trim().length < 2) {
      return _errorService.getErrorMessage('VALIDATION_TOO_SHORT');
    }
    return null;
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidPhone(value)) {
      return _errorService.getErrorMessage('AUTH_INVALID_PHONE');
    }
    return null;
  }

  String? _validateCountryCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }

    final code = value.trim();
    if (code.length < 1 || code.length > 4) {
      return 'رمز الدولة غير صالح';
    }
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      return 'رمز الدولة يجب أن يحتوي على أرقام فقط';
    }

    return null;
  }

  bool _isValidPhone(String phone) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleanedPhone.length >= 6 && cleanedPhone.length <= 12;
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'إنشاء حساب جديد',
      heading: 'إنشاء حساب جديد',
      subtitle: 'املأ البيانات التالية لإنشاء حسابك',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: _validateFullName,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              // Téléphone + indicatif : hauteur libre pour que les messages
              // d'erreur restent visibles
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(12),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: _validatePhone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        hintText: '20202020',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: TextFormField(
                      controller: _countryCodeController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(4),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: _validateCountryCode,
                      decoration: const InputDecoration(
                        labelText: 'الرمز',
                        hintText: '222',
                        prefixText: '+',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              PasswordFieldWidget(
                controller: _passwordController,
                labelText: 'كلمة المرور',
                showStrengthIndicator: true,
                showSuggestions: true,
              ),
              const SizedBox(height: AppTheme.spacingS),
              ConfirmPasswordFieldWidget(
                controller: _confirmPasswordController,
                passwordController: _passwordController,
                labelText: 'تأكيد كلمة المرور',
              ),
              const SizedBox(height: AppTheme.spacingM),
              const AppNotice(
                text:
                    'سيتم توثيق حسابك من قبل الإدارة قبل أن تتمكن من تسجيل الدخول.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: AppTheme.spacingM),
              AuthSubmitButton(
                text: 'إنشاء الحساب',
                icon: Icons.person_add_alt_1_rounded,
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
      footer: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('لديك حساب بالفعل؟', style: AppTheme.bodyMedium),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      ],
    );
  }
}
