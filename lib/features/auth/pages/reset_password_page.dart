import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/error_service.dart';
import '../../../core/services/password_validation_service.dart';
import '../../../core/widgets/password_field_widget.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkRecoverySession();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Vérifie si une session de récupération est active
  Future<void> _checkRecoverySession() async {
    setState(() => _isProcessing = true);

    try {
      // Vérifier si l'utilisateur a une session de récupération active
      final session = _supabase.auth.currentSession;
      
      // Si pas de session, essayer de vérifier avec le hash de l'URL
      if (session == null) {
        // Attendre un peu pour que Supabase traite le lien de récupération
        await Future.delayed(const Duration(seconds: 1));
        
        // Vérifier à nouveau
        final newSession = _supabase.auth.currentSession;
        if (newSession == null) {
          if (mounted) {
            _showErrorDialog(
              'لم يتم العثور على رابط إعادة تعيين صالح.\n\n'
              'يرجى فتح رابط إعادة التعيين من البريد الإلكتروني داخل التطبيق، أو طلب رابط جديد.',
            );
            // Ne pas rediriger, permettre à l'utilisateur d'entrer manuellement le token
            setState(() => _isProcessing = false);
            return;
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'خطأ في التحقق من رابط إعادة التعيين: ${_errorService.analyzeException(e)}',
        );
        setState(() => _isProcessing = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Vérifier la validation du mot de passe
      final validationResult = _passwordService.validatePassword(
        _newPasswordController.text,
      );

      if (!validationResult.isValid) {
        throw Exception(validationResult.errors.first);
      }

      // Mettre à jour le mot de passe
      await _supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Déconnexion pour forcer une nouvelle connexion avec le nouveau mot de passe
      await _supabase.auth.signOut();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(_errorService.analyzeException(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('تم إعادة تعيين كلمة المرور'),
            ],
          ),
          content: const Text(
            'تم إعادة تعيين كلمة المرور بنجاح!\n\n'
            'يرجى تسجيل الدخول بكلمة المرور الجديدة.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('خطأ في إعادة تعيين كلمة المرور'),
            ],
          ),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('جاري التحقق...'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعادة تعيين كلمة المرور'),
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
                'إعادة تعيين كلمة المرور',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل كلمة المرور الجديدة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Nouveau mot de passe avec validation avancée
              PasswordFieldWidget(
                controller: _newPasswordController,
                labelText: 'كلمة المرور الجديدة',
                showStrengthIndicator: true,
                showSuggestions: true,
              ),
              const SizedBox(height: 16),

              // Confirmation du nouveau mot de passe
              ConfirmPasswordFieldWidget(
                controller: _confirmPasswordController,
                passwordController: _newPasswordController,
                labelText: 'تأكيد كلمة المرور الجديدة',
              ),
              const SizedBox(height: 32),

              // Bouton de réinitialisation
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

