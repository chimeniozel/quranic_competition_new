import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_validation_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/password_field_widget.dart';
import '../../../core/widgets/ui_components.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _errorService = ErrorService();
  final _passwordService = PasswordValidationService();
  final _supabase = Supabase.instance.client;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  List<String> _passwordHistory = []; // Pour éviter la réutilisation

  @override
  void initState() {
    super.initState();
    _loadPasswordHistory();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Charge l'historique des mots de passe (simulation)
  Future<void> _loadPasswordHistory() async {
    // Dans une vraie application, cela viendrait de la base de données
    // Pour l'instant, on simule avec une liste vide
    setState(() {
      _passwordHistory = [];
    });
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Vérifier le mot de passe actuel
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Vérifier que le nouveau mot de passe n'est pas identique à l'ancien
      if (_currentPasswordController.text == _newPasswordController.text) {
        throw Exception('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
      }

      // Vérifier réellement le mot de passe actuel (il n'était jamais
      // contrôlé : toute session ouverte pouvait changer le mot de passe)
      final email = currentUser.email;
      if (email == null || email.isEmpty) {
        throw Exception('تعذر التحقق من الحساب');
      }
      try {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: _currentPasswordController.text,
        );
      } on AuthException {
        throw Exception('كلمة المرور الحالية غير صحيحة');
      }

      // Vérifier l'historique des mots de passe
      final validationResult = _passwordService.validatePasswordWithHistory(
        _newPasswordController.text,
        _passwordHistory,
      );

      if (!validationResult.isValid) {
        throw Exception(validationResult.errors.first);
      }

      // Changer le mot de passe
      await _supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Mettre à jour l'historique (simulation)
      _passwordHistory.add(_currentPasswordController.text);

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '').trim();
      _showErrorDialog(
        e is Exception && !message.contains('AuthException')
            ? message
            : _errorService.analyzeException(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    ModernDialog.showSuccess(
      context,
      title: 'تم تغيير كلمة المرور',
      message:
          'تم تغيير كلمة المرور بنجاح!\n\n'
          'ستحتاج إلى تسجيل الدخول مرة أخرى بكلمة المرور الجديدة.',
      onConfirm: () async {
        Navigator.of(context).pop();
        // Déconnexion réelle : sinon /login renvoyait aussitôt vers l'accueil
        await AuthService().signOut();
        if (mounted) context.go('/login');
      },
    );
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(
      context,
      title: 'خطأ في تغيير كلمة المرور',
      message: error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AppGradientHeader(
              icon: Icons.lock_reset_rounded,
              title: 'تغيير كلمة المرور',
              subtitle: 'أدخل كلمة المرور الحالية ثم الجديدة',
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSection(
                    icon: Icons.password_rounded,
                    title: 'كلمة المرور',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrentPassword,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور الحالية',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        _obscureCurrentPassword =
                                            !_obscureCurrentPassword,
                                  ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return _errorService.getErrorMessage(
                                'VALIDATION_REQUIRED',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        PasswordFieldWidget(
                          controller: _newPasswordController,
                          labelText: 'كلمة المرور الجديدة',
                          showStrengthIndicator: true,
                          showSuggestions: true,
                          passwordHistory: _passwordHistory,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        ConfirmPasswordFieldWidget(
                          controller: _confirmPasswordController,
                          passwordController: _newPasswordController,
                          labelText: 'تأكيد كلمة المرور الجديدة',
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _changePassword,
                          style: AppButtonStyles.filled(AppTheme.primaryColor),
                          icon:
                              _isLoading
                                  ? const AppButtonLoader()
                                  : const Icon(Icons.check_rounded),
                          label: Text(
                            _isLoading
                                ? 'جاري التغيير...'
                                : 'تغيير كلمة المرور',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  const AppNotice(
                    icon: Icons.tips_and_updates_rounded,
                    text:
                        'نصائح الأمان:\n'
                        '• استخدم كلمة مرور قوية ومختلفة عن حساباتك الأخرى\n'
                        '• تجنب استخدام المعلومات الشخصية\n'
                        '• لا تشارك كلمة المرور مع أي شخص',
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
