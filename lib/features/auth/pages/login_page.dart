import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorColor),
              SizedBox(width: AppTheme.spacingS),
              Text('خطأ في تسجيل الدخول'),
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

  void _showVerificationRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppTheme.warningColor),
              const SizedBox(width: AppTheme.spacingS),
              const Text('حساب غير محقق'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حسابك غير محقق حالياً. يجب أن يتم التحقق من حسابك من قبل الإدارة للوصول إلى المنصة.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: AppTheme.spacingS),
              Text(
                'يرجى التواصل مع الإدارة أو المحاولة لاحقاً.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
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
      appBar: const ModernAppBar(title: 'تسجيل الدخول'),
      body: ModernPullToRefresh(
        onRefresh: () async {
          // Rafraîchir la page si nécessaire
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header avec icône
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.login, size: 60, color: Colors.white),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'مرحباً بك',
                        style: AppTheme.headingMedium.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'سجل دخولك للوصول إلى المسابقة القرآنية',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),

                // Champs de saisie modernes
                ModernTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'أدخل بريدك الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppTheme.spacingS),

                ModernTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  hint: 'أدخل كلمة المرور',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppTheme.spacingXL),

                // Bouton de connexion
                PrimaryButton(
                  text: 'تسجيل الدخول',
                  icon: Icons.login,
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
                SecondaryButton(
                  text: 'العودة إلى الصفحة الرئيسية',
                  icon: Icons.home,
                  onPressed: () => context.go('/participant_home_page'),
                  fullWidth: true,
                ),
                const SizedBox(height: AppTheme.spacingL),

                // Informations supplémentaires
                ModernCard(
                  backgroundColor: AppTheme.infoColor.withOpacity(0.1),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.infoColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Text(
                              'تأكد من استخدام بيانات الدخول الصحيحة للوصول إلى حسابك',
                              style: TextStyle(
                                color: AppTheme.infoColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Text(
                              'يجب أن يكون حسابك محققاً من قبل الإدارة للوصول',
                              style: TextStyle(
                                color: AppTheme.warningColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
