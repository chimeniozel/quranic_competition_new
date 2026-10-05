import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../widgets/auth_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _errorService = ErrorService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _prefillLastEmail();
  }

  /// Pré-remplit l'email du dernier compte connecté sur cet appareil
  Future<void> _prefillLastEmail() async {
    final email = await AuthService.getLastEmail();
    if (!mounted || email == null || _emailController.text.isNotEmpty) return;
    setState(() => _emailController.text = email);
    // L'email est déjà là : on place le curseur sur le mot de passe
    _passwordFocus.requestFocus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final error = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (error != null) {
        _showErrorDialog(error);
      } else {
        // Connexion réussie - Vérifier si l'utilisateur est vérifié
        final user = await _authService.getUserProfile();

        if (user != null && user.isVerified) {
          // Utilisateur vérifié - Navigation vers la page appropriée
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_errorService.getSuccessMessage('login_success')),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 2),
              ),
            );

            switch (user.role) {
              case 'admin':
              case 'super_admin':
                context.go('/admin/dashboard');
                break;
              case 'jury':
                context.go('/jury/home');
                break;
              case 'membre':
              case 'membre_ordinaire':
              case 'participant':
              case 'member':
                context.go('/participant_home_page');
                break;
              default:
                context.go('/');
            }
          }
        } else {
          // Utilisateur non vérifié - Déconnexion et affichage d'erreur
          await _authService.signOut();
          if (mounted) {
            _showVerificationRequiredDialog();
          }
        }
      }
    } catch (e) {
      _showErrorDialog(_errorService.analyzeException(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String error) {
    ModernDialog.showError(
      context,
      title: 'خطأ في تسجيل الدخول',
      message: error,
    );
  }

  void _showVerificationRequiredDialog() {
    ModernDialog.showWarning(
      context,
      title: 'حساب غير محقق',
      message:
          'حسابك غير محقق حالياً. يجب أن يتم التحقق من حسابك من قبل الإدارة للوصول إلى المنصة.\n\n'
          'يرجى التواصل مع الإدارة أو المحاولة لاحقاً.',
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (value.length < 6) {
      return _errorService.getErrorMessage('AUTH_PASSWORD_TOO_SHORT');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'تسجيل الدخول',
      heading: 'مرحباً بك',
      subtitle: 'سجل دخولك للوصول إلى مسابقة أهل القرآن الواتسابية',
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'أدخل بريدك الإلكتروني',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                validator: _validatePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  hintText: 'أدخل كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('نسيت كلمة المرور؟'),
                ),
              ),
              AuthSubmitButton(
                text: 'تسجيل الدخول',
                icon: Icons.login_rounded,
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
            Text('ليس لديك حساب؟', style: AppTheme.bodyMedium),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('إنشاء حساب جديد'),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => context.go('/participant_home_page'),
          icon: const Icon(Icons.home_rounded),
          label: const Text('العودة إلى الصفحة الرئيسية'),
        ),
      ],
    );
  }
}
