import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/error_service.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    if (value == null || value.isEmpty) {
      return _errorService.getErrorMessage('VALIDATION_REQUIRED');
    }
    if (!_isValidEmail(value)) {
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'تسجيل الدخول',
        leading:
            Navigator.of(context).canPop()
                ? IconButton(
                  icon: const FaIcon(FontAwesomeIcons.chevronRight, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
                : null,
      ),
      body: ModernPullToRefresh(
        onRefresh: () async {
          // Rafraîchir la page si nécessaire
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header avec icône
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
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
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'مرحباً بك',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'سجل دخولك للوصول إلى مسابقة أهل القرآن الواتسابية',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),

                // Champs de saisie modernes
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
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
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

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    hintText: 'أدخل كلمة المرور',
                    prefixIcon: const FaIcon(FontAwesomeIcons.lock, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? FontAwesomeIcons.eyeSlash.data
                            : FontAwesomeIcons.eye.data,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
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
                const SizedBox(height: AppTheme.spacingXL),

                // Bouton de connexion
                PrimaryButton(
                  text: 'تسجيل الدخول',
                  icon: FontAwesomeIcons.rightToBracket.data,
                  onPressed: _submit,
                  isLoading: _isLoading,
                  fullWidth: true,
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Liens d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('إنشاء حساب جديد'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Bouton pour accéder à la page d'accueil
                TextButton(
                  onPressed: () => context.go('/participant_home_page'),
                  child: const Text('العودة إلى الصفحة الرئيسية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
