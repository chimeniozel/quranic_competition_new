import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_validation_service.dart';
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

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog(_errorService.analyzeException(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    ModernDialog.showSuccess(
      context,
      title: 'تم تغيير كلمة المرور',
      message:
          'تم تغيير كلمة المرور بنجاح!\n\n'
          'ستحتاج إلى تسجيل الدخول مرة أخرى بكلمة المرور الجديدة.',
      onConfirm: () {
        Navigator.of(context).pop();
        context.go('/login');
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
      appBar: AppBar(
        title: const Text('تغيير كلمة المرور'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header avec icône
              Icon(
                Icons.lock_reset,
                size: 80,
                color: Colors.deepPurple.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'تغيير كلمة المرور',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل كلمة المرور الحالية والجديدة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Mot de passe actuel
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _errorService.getErrorMessage('VALIDATION_REQUIRED');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nouveau mot de passe avec validation avancée
              PasswordFieldWidget(
                controller: _newPasswordController,
                labelText: 'كلمة المرور الجديدة',
                showStrengthIndicator: true,
                showSuggestions: true,
                passwordHistory: _passwordHistory,
              ),
              const SizedBox(height: 16),

              // Confirmation du nouveau mot de passe
              ConfirmPasswordFieldWidget(
                controller: _confirmPasswordController,
                passwordController: _newPasswordController,
                labelText: 'تأكيد كلمة المرور الجديدة',
              ),
              const SizedBox(height: 32),

              // Bouton de changement
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تغيير كلمة المرور',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              const SizedBox(height: 16),

              // Informations de sécurité
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'نصائح الأمان:',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• استخدم كلمة مرور قوية ومختلفة عن الحسابات الأخرى\n'
                      '• تجنب استخدام المعلومات الشخصية\n'
                      '• لا تشارك كلمة المرور مع أي شخص\n'
                      '• قم بتغيير كلمة المرور بانتظام',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
